<?php

namespace App\Notifications;

use App\Models\Contract;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class ContractCompanyApprovedNotification extends Notification implements ShouldQueue
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
            'type' => 'contract_company_approved',
            'contract_id' => $this->contract->id,
            'title' => 'تم اعتماد العقد نهائياً',
            'message' => 'تم اعتماد العقد ' . $this->contract->title . ' من الطرفين. يمكنك الآن الدفع.',
            'workspace_id' => $this->contract->workspace_id,
        ];
    }

    public function toFcm($notifiable): array
    {
        return [
            'title' => 'اعتماد نهائي للعقد',
            'body' => 'تم اعتماد العقد ' . $this->contract->title . ' من الطرفين.',
            'data' => ['type' => 'contract.company_approved', 'id' => (string) $this->contract->id],
        ];
    }
    public function toBroadcast($notifiable): array
    {
        return $this->toDatabase($notifiable);
    }
}