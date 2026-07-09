<?php

namespace App\Domains\File;

use App\Models\FileEntry;
use App\Models\DocumentDefinition;
use App\Models\Workspace;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Storage;

class FileController extends Controller
{
    public function index(Workspace $workspace): JsonResponse
    {
        $files = $workspace->files()->with('documentDefinition', 'reviewer')->latest()->get();
        $definitions = $workspace->documentDefinitions()->orderBy('sort_order')->get();

        return response()->json(['files' => $files, 'definitions' => $definitions]);
    }

    public function upload(Request $request, Workspace $workspace): JsonResponse
    {
        $request->validate([
            'file' => 'required|file|mimes:pdf,jpg,jpeg,png,doc,docx,xls,xlsx,zip|max:102400',
            'name' => 'nullable|string|max:255',
            'document_definition_id' => 'nullable|exists:document_definitions,id',
            'contract_id' => 'nullable|exists:contracts,id',
            'contract_required_document_id' => 'nullable|exists:contract_required_documents,id',
        ]);

        $path = $request->file('file')->store('workspace-' . $workspace->id, 'public');

        $file = $workspace->files()->create([
            'document_definition_id' => $request->document_definition_id,
            'contract_id' => $request->contract_id,
            'contract_required_document_id' => $request->contract_required_document_id,
            'uploaded_by_type' => get_class($request->user()),
            'uploaded_by_id' => $request->user()->id,
            'file_url' => Storage::url($path),
            'name' => $request->name ?? $request->file('file')->getClientOriginalName(),
            'type' => $request->file('file')->getMimeType(),
            'size' => $request->file('file')->getSize(),
            'status' => 'pending',
        ]);

        $auditData = [
            'auditable_type' => FileEntry::class,
            'auditable_id' => $file->id,
            'action' => 'file.uploaded',
            'ip_address' => $request->ip(),
        ];
        if ($request->user() instanceof \App\Models\User) {
            $auditData['user_id'] = $request->user()->id;
        }
        AuditLog::create($auditData);

        return response()->json(['file' => $file->load('documentDefinition')], 201);
    }

    public function review(Request $request, FileEntry $file): JsonResponse
    {
        if (!$request->user()->isSuperAdmin()) {
            abort(403, 'Only Super Admin can review documents');
        }

        $request->validate([
            'action' => 'required|in:approved,rejected',
            'rejection_reason' => 'required_if:action,rejected|nullable|string',
        ]);

        $file->update([
            'status' => $request->action,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'rejection_reason' => $request->rejection_reason,
        ]);

        $auditData = [
            'auditable_type' => FileEntry::class,
            'auditable_id' => $file->id,
            'action' => 'file.' . $request->action,
            'ip_address' => $request->ip(),
        ];
        if ($request->user() instanceof \App\Models\User) {
            $auditData['user_id'] = $request->user()->id;
        }
        AuditLog::create($auditData);

        return response()->json(['file' => $file->fresh()->load('documentDefinition', 'reviewer')]);
    }

    public function storeDefinition(Request $request, Workspace $workspace): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'is_required' => 'boolean',
        ]);

        $definition = $workspace->documentDefinitions()->create([
            'name' => $request->name,
            'description' => $request->description,
            'is_required' => $request->is_required ?? true,
            'sort_order' => $workspace->documentDefinitions()->count(),
        ]);

        return response()->json(['definition' => $definition], 201);
    }

    public function destroyDefinition(Request $request, Workspace $workspace, DocumentDefinition $documentDefinition): JsonResponse
    {
        $documentDefinition->delete();
        return response()->json(['message' => 'تم حذف تعريف المستند']);
    }
}
