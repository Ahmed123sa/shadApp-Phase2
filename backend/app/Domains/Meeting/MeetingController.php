<?php

namespace App\Domains\Meeting;

use App\Models\Meeting;
use App\Models\User;
use App\Models\Workspace;
use App\Models\AuditLog;
use App\Events\MeetingCreated;
use App\Http\Requests\StoreMeetingRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Http;

class MeetingController extends Controller
{
    public function allMeetings(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Meeting::class);

        $user = $request->user();
        $meetings = Meeting::with('workspace.client', 'contract', 'approval')
            ->when($user->isAccountManager(), fn($q) => $q->whereHas('workspace', fn($q) => $q->where('manager_id', $user->id)))
            ->latest()
            ->paginate(30);

        return response()->json(['meetings' => $meetings]);
    }

    public function index(Request $request, Workspace $workspace): JsonResponse
    {
        $this->authorize('viewAny', Meeting::class);

        return response()->json(['meetings' => $workspace->meetings()->with('contract', 'approval')->latest()->paginate(30)]);
    }

    public function store(StoreMeetingRequest $request, Workspace $workspace): JsonResponse
    {
        if (!$request->user()->isSuperAdmin() && $workspace->manager_id !== $request->user()->id) {
            return response()->json(['message' => 'غير مصرح'], 403);
        }

        $meetingData = [
            'workspace_id' => $workspace->id,
            'title' => $request->title,
            'scheduled_at' => $request->scheduled_at,
            'duration_minutes' => $request->duration_minutes ?? 30,
            'contract_id' => $request->contract_id,
            'approval_id' => $request->approval_id,
            'notes' => $request->notes,
            'status' => 'scheduled',
            'created_by' => $request->user()->id,
        ];

        // Zoom API integration (if configured)
        $zoomConfig = config('services.zoom');
        if ($zoomConfig && $zoomConfig['client_id'] ?? null) {
            try {
                $zoomMeeting = $this->createZoomMeeting($request->title, $request->scheduled_at, $request->duration_minutes ?? 30);
                $meetingData['zoom_meeting_id'] = $zoomMeeting['id'] ?? null;
                $meetingData['link'] = $zoomMeeting['join_url'] ?? null;
                $meetingData['passcode'] = $zoomMeeting['password'] ?? null;
            } catch (\Exception $e) {
                report($e);
            }
        }

        $meeting = Meeting::create($meetingData);

        MeetingCreated::dispatch($meeting);

        AuditLog::create([
            'auditable_type' => Meeting::class,
            'auditable_id' => $meeting->id,
            'user_id' => $request->user()->id,
            'action' => 'meeting.created',
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['meeting' => $meeting], 201);
    }

    public function update(Request $request, Meeting $meeting): JsonResponse
    {
        $this->authorize('update', $meeting);

        $meeting->update($request->only(['title', 'scheduled_at', 'duration_minutes', 'notes', 'status']));

        AuditLog::create([
            'auditable_type' => Meeting::class,
            'auditable_id' => $meeting->id,
            'user_id' => $request->user()->id,
            'action' => 'meeting.updated',
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['meeting' => $meeting->fresh()]);
    }

    public function destroy(Meeting $meeting): JsonResponse
    {
        $this->authorize('delete', $meeting);

        $meeting->delete();

        return response()->json(['message' => 'تم حذف الاجتماع']);
    }

    protected function createZoomMeeting(string $title, string $scheduledAt, int $duration): array
    {
        $accountId = config('services.zoom.account_id');
        $clientId = config('services.zoom.client_id');
        $clientSecret = config('services.zoom.client_secret');

        $tokenResponse = Http::asForm()->post('https://zoom.us/oauth/token', [
            'grant_type' => 'account_credentials',
            'account_id' => $accountId,
            'client_id' => $clientId,
            'client_secret' => $clientSecret,
        ]);

        $accessToken = $tokenResponse->json('access_token');

        $response = Http::withToken($accessToken)->post('https://api.zoom.us/v2/users/me/meetings', [
            'topic' => $title,
            'type' => 2,
            'start_time' => $scheduledAt,
            'duration' => $duration,
            'timezone' => config('app.timezone', 'UTC'),
            'settings' => ['host_video' => true, 'participant_video' => true],
        ]);

        return $response->json();
    }
}
