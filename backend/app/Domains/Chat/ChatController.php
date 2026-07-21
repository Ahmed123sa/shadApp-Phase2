<?php

namespace App\Domains\Chat;

use App\Models\ChatMessage;
use App\Models\Approval;
use App\Models\Workspace;
use App\Models\AuditLog;
use App\Domains\Chat\MessageSent;
use App\Notifications\ChatMessageSentNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Services\ApprovalPdfService;

class ChatController extends Controller
{
    public function index(Workspace $workspace): JsonResponse
    {
        $messages = $workspace->chatMessages()
            ->with('sender', 'approval.certificate')
            ->latest()
            ->take(100)
            ->get()
            ->reverse()
            ->values();

        return response()->json(['messages' => $messages]);
    }

    public function store(Request $request, Workspace $workspace): JsonResponse
    {
        $request->validate([
            'message' => 'nullable|string',
            'type' => 'in:text,file,meeting',
            'file' => 'nullable|file|max:102400',
            'metadata' => 'nullable|array',
            'requires_action' => 'boolean',
        ]);

        $sender = $request->user();
        if (!$sender) {
            Log::warning('Chat: no authenticated sender', [
                'sanctum_guard' => \Illuminate\Support\Facades\Auth::guard('sanctum')->check(),
                'client_guard' => \Illuminate\Support\Facades\Auth::guard('client')->check(),
                'ws_id' => $workspace->id,
            ]);
            return response()->json(['message' => 'غير مصرح'], 401);
        }
        $senderType = get_class($sender);

        $fileUrl = null;
        $fileName = null;
        $fileType = null;
        $fileSize = null;

        if ($request->hasFile('file')) {
            $path = $request->file('file')->store('chat-attachments', 'public');
            $fileUrl = Storage::url($path);
            $fileName = $request->file('file')->getClientOriginalName();
            $fileType = $request->file('file')->getMimeType();
            $fileSize = $request->file('file')->getSize();
        }

        $message = $workspace->chatMessages()->create([
            'sender_type' => $senderType,
            'sender_id' => $sender->id,
            'message' => $request->message,
            'type' => $request->hasFile('file') ? 'file' : ($request->type ?? 'text'),
            'file_url' => $fileUrl,
            'metadata' => $request->metadata,
            'requires_action' => $request->requires_action ?? false,
        ]);

        if ($request->boolean('requires_action')) {
            $approval = $workspace->approvals()->create([
                'title' => 'موافقة مطلوبة: ' . Str::limit($request->message ?? 'رسالة', 50),
                'description' => $request->message,
                'approvable_type' => 'chat_message',
                'approvable_id' => $message->id,
                'reference_no' => 'APP-' . strtoupper(Str::random(10)),
                'requested_by' => $sender->id,
                'status' => 'pending',
            ]);
            $message->update(['approval_id' => $approval->id]);
        }

        // If a file was uploaded, also save as FileEntry
        if ($request->hasFile('file')) {
            $workspace->files()->create([
                'uploaded_by_type' => $senderType,
                'uploaded_by_id' => $sender->id,
                'file_url' => $fileUrl,
                'name' => $fileName,
                'type' => $fileType,
                'size' => $fileSize,
                'status' => $senderType === \App\Models\Client::class ? 'pending' : 'approved',
            ]);
        }

        try {
            broadcast(new MessageSent($message))->toOthers();
        } catch (\Exception $e) {
            Log::warning('Chat broadcast failed (non-critical): ' . $e->getMessage());
        }

        // إرسال إشعار FCM للطرف الآخر
        $recipient = null;
        if ($senderType === \App\Models\User::class) {
            $recipient = $workspace->client;
        } elseif ($senderType === \App\Models\Client::class) {
            $recipient = $workspace->manager;
        }
        if ($recipient) {
            try {
                $recipient->notify(new ChatMessageSentNotification($message));
            } catch (\Exception $e) {
                Log::warning('Chat notification failed: ' . $e->getMessage());
            }
        }

        return response()->json(['message' => $message->load('sender')], 201);
    }

    public function toggleRequireAction(Request $request, ChatMessage $chatMessage): JsonResponse
    {
        $newValue = !$chatMessage->requires_action;

        $chatMessage->update(['requires_action' => $newValue]);

        // When enabling requires_action, create an Approval record automatically
        if ($newValue && !$chatMessage->approval_id) {
            $workspace = $chatMessage->workspace;
            $approval = $workspace->approvals()->create([
                'title' => 'موافقة مطلوبة: ' . Str::limit($chatMessage->message ?? 'رسالة', 50),
                'description' => $chatMessage->message,
                'approvable_type' => 'chat_message',
                'approvable_id' => $chatMessage->id,
                'reference_no' => 'APP-' . strtoupper(Str::random(10)),
                'requested_by' => $request->user()?->id ?? $chatMessage->sender_id,
                'status' => 'pending',
            ]);

            $chatMessage->update(['approval_id' => $approval->id]);
        }

        return response()->json(['message' => $chatMessage->fresh()->load('approval')]);
    }

    public function respond(Request $request, ChatMessage $chatMessage): JsonResponse
    {
        $request->validate([
            'action' => 'required|in:approved,edit_requested',
            'reason' => 'nullable|string|max:1000',
        ]);

        $user = $request->user();
        $signature = $user instanceof \App\Models\Client ? $user->signature_data : null;

        $chatMessage->update([
            'action_taken' => true,
            'action_result' => $request->action,
            'responded_at' => now(),
        ]);

        // If there's a linked approval, update it too
        $approval = $chatMessage->approval;
        if ($approval) {
            $approval->update([
                'status' => $request->action === 'approved' ? 'approved' : 'edit_requested',
                'client_action' => $request->action,
                'signature' => $signature,
                'responded_at' => now(),
                'reason' => $request->input('reason'),
            ]);

            if ($request->action === 'approved') {
                $pdfPath = app(ApprovalPdfService::class)->generateCertificate($approval);
                $approval->certificate()->create([
                    'pdf_url' => $pdfPath,
                    'generated_at' => now(),
                ]);
            }

            if ($approval->requester) {
                $approval->requester->notify(new \App\Notifications\ApprovalRespondedNotification($approval));
            }
        }

        AuditLog::create([
            'auditable_type' => ChatMessage::class,
            'auditable_id' => $chatMessage->id,
            'action' => 'chat.responded.' . $request->action,
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['message' => $chatMessage->fresh()->load('approval.certificate')]);
    }

    public function markAsRead(Workspace $workspace, Request $request): JsonResponse
    {
        $user = $request->user();
        $senderType = get_class($user);

        $workspace->chatMessages()
            ->where('sender_type', '!=', $senderType)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'done']);
    }
}
