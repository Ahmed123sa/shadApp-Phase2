<?php

namespace App\Domains\Payment;

use App\Models\Client;
use App\Models\Payment;
use App\Models\User;
use App\Models\Workspace;
use App\Models\AuditLog;
use App\Events\PaymentCreated;
use App\Events\PaymentReviewed;
use App\Http\Requests\StorePaymentRequest;
use App\Http\Requests\ReviewPaymentRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use App\Models\Contract;
use App\Events\ContractCompanyApproved;

class PaymentController extends Controller
{
    const BUSINESS_METHODS = ['bank_transfer', 'swift', 'corporate_account'];
    const INDIVIDUAL_METHODS = ['instapay', 'vodafone_cash', 'mobile_wallet'];

    public function pending(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Payment::class);

        $user = $request->user();
        $query = Payment::with(['workspace.client', 'contract'])
            ->where('status', 'pending');

        if ($user->isAccountManager()) {
            $clientIds = $user->managedClients()->pluck('id');
            $query->whereIn('client_id', $clientIds);
        }

        return response()->json([
            'payments' => $query->latest()->paginate(30),
        ]);
    }

    public function index(Request $request, Workspace $workspace): JsonResponse
    {
        $this->authorize('viewAny', Payment::class);

        $client = $workspace->client;
        $methods = $client->client_type === 'individual' ? self::INDIVIDUAL_METHODS : self::BUSINESS_METHODS;

        return response()->json([
            'payments' => $workspace->payments()->with('contract')->latest()->get(),
            'available_methods' => $methods,
            'client_type' => $client->client_type,
        ]);
    }

    public function store(StorePaymentRequest $request, Workspace $workspace): JsonResponse
    {
        $client = $workspace->client;
        $methods = $client->client_type === 'individual' ? self::INDIVIDUAL_METHODS : self::BUSINESS_METHODS;

        $proofFileUrl = [];
        if ($request->hasFile('proof_files')) {
            foreach ($request->file('proof_files') as $file) {
                $path = $file->store('payment-proofs/workspace-' . $workspace->id, 'public');
                $proofFileUrl[] = Storage::url($path);
            }
        }
        $proofFileUrl = !empty($proofFileUrl) ? $proofFileUrl : null;

        // Auto-link to the latest company_approved or completed contract
        $lastContract = $workspace->contracts()
            ->whereIn('status', ['company_approved', 'completed'])
            ->latest()
            ->first();

        // Prevent duplicate pending payment for the same contract
        if ($lastContract && $workspace->payments()->where('contract_id', $lastContract->id)->where('status', 'pending')->exists()) {
            return response()->json(['message' => 'يوجد طلب دفع معلق لهذا العقد بالفعل'], 422);
        }

        $payment = $workspace->payments()->create([
            'client_id' => $workspace->client_id,
            'contract_id' => $lastContract?->id,
            'amount' => $request->amount,
            'currency' => $request->currency ?? 'SAR',
            'method_type' => $request->method_type,
            'proof_file_url' => $proofFileUrl,
            'notes' => $request->notes,
            'status' => 'pending',
        ]);

        PaymentCreated::dispatch($payment);

        AuditLog::create([
            'auditable_type' => Payment::class,
            'auditable_id' => $payment->id,
            'action' => 'payment.submitted',
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['payment' => $payment], 201);
    }

    public function update(Request $request, Workspace $workspace, Payment $payment): JsonResponse
    {
        if ($payment->status !== 'pending') {
            return response()->json(['message' => 'لا يمكن تعديل دفع تمت مراجعته'], 422);
        }

        $request->validate([
            'amount' => 'nullable|numeric|min:0',
            'currency' => 'nullable|string|size:3',
            'method_type' => 'nullable|string',
            'proof_file' => 'nullable|file|max:102400',
        ]);

        if ($request->has('amount')) $payment->amount = $request->amount;
        if ($request->has('currency')) $payment->currency = $request->currency;
        if ($request->has('method_type')) $payment->method_type = $request->method_type;
        if ($request->hasFile('proof_files')) {
            $proofFileUrl = [];
            foreach ($request->file('proof_files') as $file) {
                $path = $file->store('payment-proofs/workspace-' . $workspace->id, 'public');
                $proofFileUrl[] = Storage::url($path);
            }
            $payment->proof_file_url = $proofFileUrl;
        }
        $payment->save();

        return response()->json(['payment' => $payment->fresh()]);
    }

    public function review(ReviewPaymentRequest $request, Payment $payment): JsonResponse
    {

        $payment->update([
            'status' => 'approved',
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        $workspace = $payment->workspace;
        $workspace = $workspace->fresh();

        $reviewerName = $request->user()?->name ?? 'system';
        $workspace->contracts()->where('status', 'client_approved')->each(function (Contract $contract) use ($reviewerName) {
            $contract->update([
                'status' => 'company_approved',
                'company_signed_at' => now(),
                'company_signature_data' => $reviewerName,
                'company_signature_type' => 'text',
            ]);
            ContractCompanyApproved::dispatch($contract, true);
        });
        $workspace->contracts()->where('status', 'company_approved')->update(['status' => 'completed']);
        $payment->client->update(['payment_status' => 'approved']);

        $contractApproved = $workspace->contracts()->whereIn('status', ['completed', 'company_approved', 'client_approved'])->exists();
        $paymentApproved = true;

        if ($contractApproved && $paymentApproved) {
            $workspace->update(['status' => 'active', 'activated_at' => now()]);
            Log::info('Workspace activated after payment approval', ['workspace_id' => $workspace->id]);
        } else {
            Log::warning('Workspace NOT activated on payment approval', [
                'workspace_id' => $workspace->id,
                'has_approved_contracts' => $contractApproved,
                'payment_id' => $payment->id,
                'contract_statuses' => $workspace->contracts()->pluck('status')->toArray(),
            ]);
        }

        PaymentReviewed::dispatch($payment, 'approved');

        AuditLog::create([
            'auditable_type' => Payment::class,
            'auditable_id' => $payment->id,
            'user_id' => $request->user()->id,
            'action' => 'payment.approved',
            'ip_address' => $request->ip(),
        ]);

        $workspace->load('payments', 'contracts');

        return response()->json([
            'payment' => $payment->fresh(),
            'workspace' => $workspace,
        ]);
    }
}
