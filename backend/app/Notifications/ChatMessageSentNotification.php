<?php

namespace App\Notifications;

use App\Models\ChatMessage;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class ChatMessageSentNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public ChatMessage $message;

    public function __construct(ChatMessage $message)
    {
        $this->message = $message;
    }

    public function via($notifiable): array
    {
        return ['database', 'broadcast', FcmChannel::class];
    }

    public function toDatabase($notifiable): array
    {
        return [
            'type' => 'chat',
            'workspace_id' => $this->message->workspace_id,
            'sender_name' => $this->message->sender?->name ?? 'مستخدم',
            'text' => $this->message->message ?? '',
            'message' => "رسالة جديدة من {$this->message->sender?->name ?? 'مستخدم'}",
        ];
    }

    public function toFcm($notifiable): array
    {
        return [
            'title' => 'رسالة جديدة',
            'body' => ($this->message->sender?->name ?? 'مستخدم') . ': ' . ($this->message->message ?? ''),
            'data' => [
                'type' => 'chat',
                'workspace_id' => (string) $this->message->workspace_id,
                'sender_name' => $this->message->sender?->name ?? 'مستخدم',
            ],
        ];
    }

    public function toBroadcast($notifiable): array
    {
        return $this->toDatabase($notifiable);
    }
}
