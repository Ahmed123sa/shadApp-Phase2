<?php

namespace App\Notifications;

use App\Models\Contract;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class ContractClientApprovedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public Contract $contract;

    public function __construct(Contract $contract)
    {
        $this->contract = $contract;
    }

    public function via($notifiable): array
    {
        return ['database', 'broadcast', FcmChannel::class];
    }

    public function toDatabase($notifiable): array
    {
        return [
            'type' => 'contract_client_approved',
            'contract_id' => $this->contract->id,
            'title' => 'اعتماد عقد من العميل',
            'message' => 'قام العميل ' . ($this->contract->workspace->client->company_name ?? '') . ' باعتماد العقد: ' . $this->contract->title,
            'workspace_id' => $this->contract->workspace_id,
        ];
    }

    public function toFcm($notifiable): array
    {
        return [
            'title' => 'اعتماد عقد من العميل',
            'body' => 'قام العميل ' . ($this->contract->workspace->client->company_name ?? '') . ' باعتماد العقد: ' . $this->contract->title,
            'data' => ['type' => 'contract', 'id' => (string) $this->contract->id],
        ];
    }
    public function toBroadcast($notifiable): array
    {
        return $this->toDatabase($notifiable);
    }
}