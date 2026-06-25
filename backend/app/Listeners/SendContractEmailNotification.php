<?php

namespace App\Listeners;

use App\Events\ContractSent;
use App\Events\ContractClientApproved;
use App\Events\ContractCompanyApproved;
use App\Events\ContractCompleted;
use App\Mail\ContractSentMail;
use App\Mail\ContractClientApprovedMail;
use App\Mail\ContractCompanyApprovedMail;
use App\Mail\ContractCompletedMail;
use App\Models\User;
use App\Notifications\ContractClientApprovedNotification;
use App\Notifications\ContractCompanyApprovedNotification;
use App\Notifications\ContractSentNotification;
use App\Notifications\ContractCompletedNotification;
use App\Services\ContractPdfService;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class SendContractEmailNotification
{
    private function getOfficialEmails(): array
    {
        return User::where('role', User::ROLE_SUPER_ADMIN)
            ->whereNotNull('official_email')
            ->pluck('official_email')
            ->toArray();
    }

    public function handleContractSent(ContractSent $event): void
    {
        $contract = $event->contract;
        $client = $contract->workspace->client;
        $manager = $contract->creator;

        if ($client->email) {
            try {
                Mail::to($client->email)->send(new ContractSentMail($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send contract sent email to client: ' . $e->getMessage());
            }
        }

        if ($manager->email) {
            try {
                Mail::to($manager->email)->send(new ContractSentMail($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send contract sent email to manager: ' . $e->getMessage());
            }
        }

        foreach ($this->getOfficialEmails() as $officialEmail) {
            try {
                Mail::to($officialEmail)->send(new ContractSentMail($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send contract sent email to official: ' . $e->getMessage());
            }
        }

        try {
            $manager->notify(new ContractSentNotification($contract));
        } catch (\Exception $e) {
            Log::warning('Failed to send contract sent notification: ' . $e->getMessage());
        }
    }

    public function handleClientApproved(ContractClientApproved $event): void
    {
        $contract = $event->contract;
        $manager = $contract->creator;

        try {
            $pdfPath = app(ContractPdfService::class)->generateWithClientSignature($contract);
        } catch (\Exception $e) {
            Log::warning('Failed to generate contract PDF: ' . $e->getMessage());
            $pdfPath = null;
        }

        $recipients = collect();

        if ($manager?->email) {
            $recipients->push(['email' => $manager->email, 'user' => $manager]);
        }

        $admins = User::where('role', User::ROLE_SUPER_ADMIN)->get();
        foreach ($admins as $admin) {
            if ($admin->email && $admin->id !== $manager?->id) {
                $recipients->push(['email' => $admin->email, 'user' => $admin]);
            }
        }

        foreach ($this->getOfficialEmails() as $officialEmail) {
            if ($recipients->doesntContain(fn($r) => $r['email'] === $officialEmail)) {
                $recipients->push(['email' => $officialEmail, 'user' => null]);
            }
        }

        foreach ($recipients as $r) {
            try {
                Mail::to($r['email'])->send(new ContractClientApprovedMail($contract, $pdfPath));
            } catch (\Exception $e) {
                Log::warning('Failed to send client approved email to ' . $r['email'] . ': ' . $e->getMessage());
            }

            if ($r['user']) {
                try {
                    $r['user']->notify(new ContractClientApprovedNotification($contract));
                } catch (\Exception $e) {
                    Log::warning('Failed to send notification: ' . $e->getMessage());
                }
            }
        }
    }

    public function handleCompanyApproved(ContractCompanyApproved $event): void
    {
        $contract = $event->contract;
        $client = $contract->workspace->client;

        try {
            $pdfPath = app(ContractPdfService::class)->generateWithBothSignatures($contract);
        } catch (\Exception $e) {
            Log::warning('Failed to generate final contract PDF: ' . $e->getMessage());
            $pdfPath = null;
        }

        if ($client->email) {
            try {
                Mail::to($client->email)->send(new ContractCompanyApprovedMail($contract, $pdfPath));
            } catch (\Exception $e) {
                Log::warning('Failed to send company approved email: ' . $e->getMessage());
            }
        }

        foreach ($this->getOfficialEmails() as $officialEmail) {
            try {
                Mail::to($officialEmail)->send(new ContractCompanyApprovedMail($contract, $pdfPath));
            } catch (\Exception $e) {
                Log::warning('Failed to send company approved email to official: ' . $e->getMessage());
            }
        }

        try {
            $client->notify(new ContractCompanyApprovedNotification($contract));
        } catch (\Exception $e) {
            Log::warning('Failed to send notification to client: ' . $e->getMessage());
        }
    }

    public function handleCompleted(ContractCompleted $event): void
    {
        $contract = $event->contract;
        $client = $contract->workspace->client;
        $manager = $contract->creator;

        $recipients = collect();

        if ($client->email) {
            try {
                Mail::to($client->email)->send(new ContractCompletedMail($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send completed email to client: ' . $e->getMessage());
            }
        }

        if ($manager && $manager->email) {
            try {
                Mail::to($manager->email)->send(new ContractCompletedMail($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send completed email to manager: ' . $e->getMessage());
            }
        }

        if ($manager) {
            $recipients->push($manager);
        }

        $admins = User::where('role', User::ROLE_SUPER_ADMIN)->get();
        foreach ($admins as $admin) {
            if ($admin->id !== $manager?->id) {
                $recipients->push($admin);
            }
        }

        foreach ($recipients as $user) {
            try {
                $user->notify(new ContractCompletedNotification($contract));
            } catch (\Exception $e) {
                Log::warning('Failed to send contract completed notification: ' . $e->getMessage());
            }
        }
    }
}
