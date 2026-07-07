<?php

namespace App\Providers;

use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\ServiceProvider;
use App\Models\User;
use App\Models\Client;

class BroadcastServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Broadcast::routes([
            'prefix' => 'api',
            'middleware' => ['auth.any:sanctum,client'],
        ]);

        require base_path('routes/channels.php');
    }
}
