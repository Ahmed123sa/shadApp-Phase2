<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class UpdateLastSeen
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);

        $user = Auth::user();
        if ($user !== null) {
            $user->last_seen_at = now();
            $user->saveQuietly();
        }

        return $response;
    }
}
