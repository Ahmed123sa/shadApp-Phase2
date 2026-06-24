<?php

namespace App\Notifications;

use App\Models\MobileNotificationToken;
use App\Services\FirebaseService;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Facades\Log;

class FcmChannel
{
    public function send($notifiable, Notification $notification): void
    {
        $data = $notification->toFcm($notifiable);

        $tokens = MobileNotificationToken::where('tokenable_id', $notifiable->id)
            ->where('tokenable_type', get_class($notifiable))
            ->pluck('token');

        if ($tokens->isEmpty()) {
            return;
        }

        $firebase = app(FirebaseService::class);

        $notifData = [
            'title' => $data['title'] ?? '',
            'body' => $data['body'] ?? '',
        ];

        $customData = $data['data'] ?? [];

        foreach ($tokens as $token) {
            try {
                $firebase->sendMessage($token, $notifData, $customData);
            } catch (\Exception $e) {
                Log::warning('FCM send failed: ' . $e->getMessage());
            }
        }
    }
}
