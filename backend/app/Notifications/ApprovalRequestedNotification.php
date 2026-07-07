<?php

namespace App\Notifications;

use App\Models\Approval;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class ApprovalRequestedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public Approval $approval;

    public function __construct(Approval $approval)
    {
        $this->approval = $approval;
    }

    public function via($notifiable): array
    {
        return ['database', 'broadcast', FcmChannel::class];
    }

    public function toDatabase($notifiable): array
    {
        return [
            'type' => 'approval_requested',
            'approval_id' => $this->approval->id,
            'title' => $this->approval->title,
            'message' => "طلب موافقة: {$this->approval->title}",
        ];
    }

    public function toFcm($notifiable): array
    {
        return [
            'title' => 'طلب موافقة',
            'body' => "طلب موافقة جديد: {$this->approval->title}",
            'data' => [
                'type' => 'approval',
                'id' => (string) $this->approval->id,
            ],
        ];
    }
    public function toBroadcast($notifiable): array
    {
        return $this->toDatabase($notifiable);
    }
}