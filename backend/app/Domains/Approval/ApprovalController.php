<?php

namespace App\Domains\Approval;

use App\Models\Approval;
use App\Models\ApprovalCertificate;
use App\Models\Workspace;
use App\Models\AuditLog;
use App\Events\ApprovalResponded;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Str;
use App\Services\ApprovalPdfService;

class ApprovalController extends Controller
{
    public function index(Workspace $workspace): JsonResponse
    {
        return response()->json(['approvals' => $workspace->approvals()->with('certificate', 'requester', 'files', 'chatMessage')->latest()->get()]);
    }

    public function store(Request $request, Workspace $workspace): JsonResponse
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'files' => 'nullable|array',
            'files.*' => 'file|max:102400',
        ]);

        $approval = $workspace->approvals()->create([
            'title' => $request->title,
            'description' => $request->description,
            'approvable_type' => 'workspace',
            'approvable_id' => $workspace->id,
            'reference_no' => 'APP-' . strtoupper(Str::random(10)),
            'requested_by' => $request->user()->id,
            'status' => 'pending',
        ]);

        // Save uploaded files
        if ($request->hasFile('files')) {
            foreach ($request->file('files') as $file) {
                $path = $file->store('approval-attachments', 'public');
                $approval->files()->create([
                    'workspace_id' => $workspace->id,
                    'uploaded_by_type' => get_class($request->user()),
                    'uploaded_by_id' => $request->user()->id,
                    'file_url' => $path,
                    'name' => $file->getClientOriginalName(),
                    'type' => $file->getMimeType(),
                    'size' => $file->getSize(),
                    'status' => 'pending',
                ]);
            }
        }

        // Create a chat message for this approval
        $msg = $workspace->chatMessages()->create([
            'sender_type' => get_class($request->user()),
            'sender_id' => $request->user()->id,
            'message' => '📋 طلب موافقة: ' . $request->title . ($request->description ? "\n" . $request->description : ''),
            'type' => 'text',
            'requires_action' => true,
            'approval_id' => $approval->id,
            'action_taken' => false,
        ]);

        AuditLog::create([
            'auditable_type' => Approval::class,
            'auditable_id' => $approval->id,
            'user_id' => $request->user()->id,
            'action' => 'approval.created',
            'metadata' => ['reference_no' => $approval->reference_no],
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['approval' => $approval->load('requester', 'files', 'chatMessage')], 201);
    }

    public function show(Approval $approval): JsonResponse
    {
        return response()->json(['approval' => $approval->load('certificate', 'requester', 'files', 'chatMessage')]);
    }

    public function respond(Request $request, Approval $approval): JsonResponse
    {
        $request->validate([
            'action' => 'required|in:approved,rejected,edit_requested',
        ]);

        $user = $request->user();
        $signature = $user instanceof \App\Models\Client ? $user->signature_data : null;

        $approval->update([
            'status' => $request->action === 'approved' ? 'approved' : ($request->action === 'rejected' ? 'rejected' : 'edit_requested'),
            'client_action' => $request->action,
            'signature' => $signature,
            'responded_at' => now(),
        ]);

        // Generate PDF certificate on approval
        $pdfPath = null;
        if ($request->action === 'approved') {
            $pdfPath = app(ApprovalPdfService::class)->generateCertificate($approval);
            $approval->certificate()->create([
                'pdf_url' => $pdfPath,
                'generated_at' => now(),
            ]);
        }

        // Update linked chat message
        $chatMsg = $approval->chatMessage;
        if ($chatMsg) {
            $chatMsg->update([
                'action_taken' => true,
                'action_result' => $request->action,
                'responded_at' => now(),
            ]);
        }

        ApprovalResponded::dispatch($approval);

        AuditLog::create([
            'auditable_type' => Approval::class,
            'auditable_id' => $approval->id,
            'action' => 'approval.' . $request->action,
            'metadata' => ['reference_no' => $approval->reference_no],
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['approval' => $approval->fresh()->load('certificate', 'files', 'chatMessage', 'requester')]);
    }
}
