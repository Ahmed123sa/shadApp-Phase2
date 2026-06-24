<?php

namespace App\Domains\Notification;

use App\Models\Client;
use App\Models\MobileNotificationToken;
use App\Models\User;
use App\Models\Workspace;
use App\Services\FirebaseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Log;

class NotificationController extends Controller
{
    public function registerToken(Request $request): JsonResponse
    {
        $request->validate([
            'token' => 'required|string',
            'device_type' => 'required|in:ios,android',
        ]);

        $user = $request->user() ?? $request->user('sanctum:client');

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        MobileNotificationToken::updateOrCreate(
            ['token' => $request->token],
            [
                'tokenable_id' => $user->id,
                'tokenable_type' => get_class($user),
                'device_type' => $request->device_type,
            ]
        );

        return response()->json(['message' => 'Token registered']);
    }

    public function sendFcm(Request $request): JsonResponse
    {
        $request->validate([
            'user_id' => 'required|integer',
            'user_type' => 'required|string',
            'title' => 'required|string|max:255',
            'body' => 'required|string',
        ]);

        try {
            $firebase = app(FirebaseService::class);
            $firebase->sendToUser(
                $request->user_id,
                $request->user_type,
                ['title' => $request->title, 'body' => $request->body]
            );

            return response()->json(['sent' => true]);
        } catch (\Exception $e) {
            Log::warning('sendFcm failed: ' . $e->getMessage());
            return response()->json(['sent' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        return response()->json([
            'notifications' => $user?->notifications()->latest()->take(20)->get() ?? [],
            'unread_count' => $user?->unreadNotifications()->count() ?? 0,
        ]);
    }

    public function markAsRead(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $notification = $user?->notifications()->where('id', $id)->first();
        if ($notification) {
            $notification->markAsRead();
        }
        return response()->json(['message' => 'done']);
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        $user = $request->user();
        $user?->unreadNotifications()->update(['read_at' => now()]);
        return response()->json(['message' => 'done']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $notification = $user?->notifications()->where('id', $id)->first();
        if ($notification) {
            $notification->delete();
        }
        return response()->json(['message' => 'done']);
    }
}
