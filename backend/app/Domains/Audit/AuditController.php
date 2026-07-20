<?php

namespace App\Domains\Audit;

use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class AuditController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::with('user', 'auditable');

        if ($request->filled('action')) {
            $query->where('action', $request->action);
        }

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->date_from);
        }

        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->date_to);
        }

        $user = $request->user();
        if ($user->isAccountManager()) {
            $clientIds = $user->managedClients()->pluck('id');
            $query->where(function ($q) use ($user, $clientIds) {
                $q->where('user_id', $user->id)
                  ->orWhereIn('auditable_id', $clientIds);
            });
        }

        return response()->json([
            'logs' => $query->latest()->paginate(25),
        ]);
    }

    public function reports(Request $request): JsonResponse
    {
        $clientModel = \App\Models\Client::query();
        $paymentModel = \App\Models\Payment::query();
        $contractModel = \App\Models\Contract::query();

        $user = $request->user();

        if ($user->isAccountManager()) {
            $clientModel->where('manager_id', $user->id);
            $paymentModel->whereHas('client', function ($q) use ($user) {
                $q->where('manager_id', $user->id);
            });
        }

        $data = [
            'total_clients' => (clone $clientModel)->count(),
            'active_workspaces' => \App\Models\Workspace::where('status', 'active')->count(),
            'pending_payments' => (clone $paymentModel)->where('status', 'pending')->count(),
            'pending_approvals' => \App\Models\Approval::where('status', 'pending')->count(),
            'recent_logins' => AuditLog::where('action', 'login')->whereDate('created_at', today())->count(),
            'contracts_by_status' => \App\Models\Contract::selectRaw('status, count(*) as count')
                ->groupBy('status')->pluck('count', 'status'),
            'payments_by_month' => (clone $paymentModel)
                ->select('amount', 'created_at')
                ->get()
                ->groupBy(fn($p) => $p->created_at->format('Y-m'))
                ->map(fn($items) => (float) $items->sum('amount')),
            'approval_stats' => [
                'approved' => \App\Models\Approval::where('status', 'approved')->count(),
                'rejected' => \App\Models\Approval::where('status', 'rejected')->count(),
                'pending' => \App\Models\Approval::where('status', 'pending')->count(),
            ],
        ];

        return response()->json($data);
    }
}
