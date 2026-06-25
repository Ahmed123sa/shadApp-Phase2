<?php

namespace App\Domains\Client;

use App\Models\Client;
use App\Models\User;
use App\Models\AuditLog;
use App\Models\Workspace;
use App\Events\ClientCreated;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ClientController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $isAM = $user instanceof \App\Models\User && $user->isAccountManager();

        $clients = Client::with('workspace')
            ->when($isAM, fn($q) => $q->where('manager_id', $user->id))
            ->latest()
            ->get();

        return response()->json(['clients' => $clients]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'company_name' => 'required|string|max:255',
            'contact_person' => 'required|string|max:255',
            'email' => 'required|email|unique:clients',
            'phone' => 'required|string|max:20',
            'contract_value' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
            'country' => 'nullable|string|max:100',
            'industry' => 'nullable|string|max:100',
            'client_type' => 'nullable|string|in:business,individual',
            'password' => 'nullable|string|min:6',
            'send_email' => 'boolean',
        ]);

        $password = $request->password ?? Str::random(12);

        $client = Client::create([
            'company_name' => $request->company_name,
            'contact_person' => $request->contact_person,
            'email' => $request->email,
            'phone' => $request->phone,
            'password' => Hash::make($password),
            'manager_id' => $request->user()->id,
            'contract_value' => $request->contract_value ?? 0,
            'country' => $request->country,
            'industry' => $request->industry,
            'client_type' => $request->client_type ?? 'business',
            'notes' => $request->notes,
        ]);

        Workspace::create([
            'client_id' => $client->id,
            'manager_id' => $request->user()->id,
            'status' => 'inactive',
        ]);

        if ($request->boolean('send_email')) {
            ClientCreated::dispatch($client, $password);
        }

        AuditLog::create([
            'auditable_type' => Client::class,
            'auditable_id' => $client->id,
            'user_id' => $request->user()->id,
            'action' => 'client.created',
            'metadata' => ['email' => $client->email],
            'ip_address' => $request->ip(),
        ]);

        return response()->json([
            'client' => $client->load('workspace'),
            'credentials' => ['email' => $client->email, 'password' => $password],
        ], 201);
    }

    public function show(Request $request, Client $client): JsonResponse
    {
        $client->load('workspace.contracts', 'workspace.payments', 'subUsers', 'payments');

        return response()->json(['client' => $client]);
    }

    public function update(Request $request, Client $client): JsonResponse
    {
        $request->validate([
            'company_name' => 'string|max:255',
            'contact_person' => 'string|max:255',
            'phone' => 'string|max:20',
            'country' => 'nullable|string|max:100',
            'industry' => 'nullable|string|max:100',
            'notes' => 'nullable|string',
            'status' => 'in:active,inactive,blocked',
            'password' => 'nullable|string|min:6',
        ]);

        $fillableFields = ['company_name', 'contact_person', 'phone', 'country', 'industry', 'notes', 'status'];
        if ($request->filled('password')) {
            $fillableFields[] = 'password';
        }

        $client->update($request->only($fillableFields));

        return response()->json(['client' => $client->fresh()->load('workspace')]);
    }

    public function sign(Request $request, Client $client): JsonResponse
    {
        if ($request->hasFile('signature_image')) {
            $request->validate(['signature_image' => 'required|image|mimes:png|max:2048']);
            $path = $request->file('signature_image')->store('signatures', 'public');
            $signatureData = Storage::url($path);
        } else {
            $request->validate(['signature' => 'required|string']);
            $signatureData = $request->signature;
        }

        $client->update([
            'signature_data' => $signatureData,
            'signed_at' => now(),
        ]);

        return response()->json(['client' => $client->fresh()]);
    }

    public function profileUpdate(Request $request, Client $client): JsonResponse
    {
        $request->validate([
            'contact_person' => 'sometimes|string|max:255',
            'avatar' => 'nullable|image|max:2048',
        ]);

        if ($request->hasFile('avatar')) {
            $path = $request->file('avatar')->store('avatars', 'public');
            $client->avatar_url = \Illuminate\Support\Facades\Storage::url($path);
        }

        $client->update($request->only(['contact_person']));

        return response()->json(['client' => $client->fresh()]);
    }

    public function destroy(Request $request, Client $client): JsonResponse
    {
        $client->delete();

        AuditLog::create([
            'auditable_type' => Client::class,
            'auditable_id' => $client->id,
            'user_id' => $request->user()->id,
            'action' => 'client.deleted',
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['message' => 'تم حذف العميل']);
    }

    public function subUsers(Client $client): JsonResponse
    {
        return response()->json(['sub_users' => $client->subUsers]);
    }
}
