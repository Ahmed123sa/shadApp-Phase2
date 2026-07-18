<?php

namespace App\Domains\Client;

use App\Models\Client;
use App\Models\User;
use App\Models\AuditLog;
use App\Models\Workspace;
use App\Events\ClientCreated;
use App\Http\Requests\StoreClientRequest;
use App\Http\Requests\UpdateClientRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ClientController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Client::class);

        $user = $request->user();
        $clients = Client::with('workspace', 'subUsers', 'payments')
            ->when($user->isAccountManager(), fn($q) => $q->where('manager_id', $user->id))
            ->latest()
            ->paginate(30);

        return response()->json(['clients' => $clients]);
    }

    public function store(StoreClientRequest $request): JsonResponse
    {

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
            'date_of_birth' => $request->date_of_birth,
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
        $this->authorize('view', $client);

        $client->load('workspace.contracts', 'workspace.payments', 'subUsers', 'payments');

        return response()->json(['client' => $client]);
    }

    public function update(UpdateClientRequest $request, Client $client): JsonResponse
    {

        $fillableFields = ['company_name', 'contact_person', 'phone', 'country', 'industry', 'notes', 'status', 'date_of_birth'];
        if ($request->filled('password')) {
            $fillableFields[] = 'password';
        }

        $client->update($request->only($fillableFields));

        return response()->json(['client' => $client->fresh()->load('workspace')]);
    }

    public function sign(Request $request, Client $client): JsonResponse
    {
        if ($request->hasFile('signature_image')) {
            $request->validate(['signature_image' => 'required|image|mimes:png,jpg,jpeg|max:5120']);
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

    public function deleteSign(Client $client): JsonResponse
    {
        $client->update([
            'signature_data' => null,
            'signed_at' => null,
        ]);
        return response()->json(['client' => $client->fresh()]);
    }

    public function profileUpdate(Request $request, Client $client): JsonResponse
    {
        $request->validate([
            'contact_person' => 'sometimes|string|max:255',
            'avatar' => 'nullable|image|max:8192',
        ]);

        $updateData = $request->only(['contact_person']);

        if ($request->hasFile('avatar')) {
            $path = $request->file('avatar')->store('avatars', 'public');
            $updateData['avatar_url'] = \Illuminate\Support\Facades\Storage::url($path);
        }

        $client->update($updateData);

        return response()->json(['client' => $client->fresh()]);
    }

    public function destroy(Request $request, Client $client): JsonResponse
    {
        $this->authorize('delete', $client);

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
