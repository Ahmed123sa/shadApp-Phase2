<?php

use App\Domains\Auth\AuthController;
use App\Domains\AccountManager\AccountManagerController;
use App\Domains\Client\ClientController;
use App\Domains\Contract\ContractController;
use App\Domains\Payment\PaymentController;
use App\Domains\Workspace\WorkspaceController;
use App\Domains\Chat\ChatController;
use App\Domains\Approval\ApprovalController;
use App\Domains\Meeting\MeetingController;
use App\Domains\File\FileController;
use App\Models\FileEntry;
use App\Domains\Audit\AuditController;
use App\Domains\Notification\NotificationController;
use App\Domains\SubUser\SubUserController;
use Illuminate\Support\Facades\Route;

// Public auth routes
Route::post('/auth/register', [AuthController::class, 'registerSuperAdmin']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/client/login', [AuthController::class, 'clientLogin']);

// Chat — allows both admin (sanctum) and client (client) auth
Route::middleware('auth.any:sanctum,client')->group(function () {
    Route::get('/workspaces/{workspace}/chat', [ChatController::class, 'index']);
    Route::post('/workspaces/{workspace}/chat', [ChatController::class, 'store']);
    Route::patch('/chat/{chatMessage}/require-action', [ChatController::class, 'toggleRequireAction']);
    Route::post('/chat/{chatMessage}/respond', [ChatController::class, 'respond']);
});

// Authenticated routes (Dashboard - SuperAdmin / AccountManager)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/me', [AuthController::class, 'me']);

    // Account Manager management (SuperAdmin only)
    Route::get('/account-managers', [AccountManagerController::class, 'index']);
    Route::post('/account-managers', [AccountManagerController::class, 'store']);
    Route::put('/account-managers/{manager}', [AccountManagerController::class, 'update']);
    Route::delete('/account-managers/{manager}', [AccountManagerController::class, 'destroy']);

    // Clients
    Route::get('/clients', [ClientController::class, 'index']);
    Route::post('/clients', [ClientController::class, 'store']);
    Route::get('/clients/{client}', [ClientController::class, 'show']);
    Route::put('/clients/{client}', [ClientController::class, 'update']);
    Route::delete('/clients/{client}', [ClientController::class, 'destroy']);
    Route::get('/clients/{client}/sub-users', [ClientController::class, 'subUsers']);
    Route::post('/clients/{client}/sub-users', [SubUserController::class, 'store']);
    Route::delete('/sub-users/{subUser}', [SubUserController::class, 'destroy']);

    // Client signature (client auth or manager)
    Route::post('/clients/{client}/sign', [ClientController::class, 'sign']);

    // Workspace
    Route::post('/workspaces', [WorkspaceController::class, 'store']);
    Route::get('/workspaces/{workspace}', [WorkspaceController::class, 'show']);
    Route::post('/workspaces/{workspace}/activate', [WorkspaceController::class, 'activate']);

    // Contracts
    Route::get('/workspaces/{workspace}/contracts', [ContractController::class, 'index']);
    Route::post('/workspaces/{workspace}/contracts', [ContractController::class, 'store']);
    Route::get('/contracts/{contract}', [ContractController::class, 'show']);
    Route::put('/contracts/{contract}', [ContractController::class, 'update']);
    Route::delete('/contracts/{contract}', [ContractController::class, 'destroy']);
    Route::post('/contracts/{contract}/send', [ContractController::class, 'send']);
    Route::post('/contracts/{contract}/client-action', [ContractController::class, 'clientAction']);
    Route::post('/contracts/{contract}/company-approve', [ContractController::class, 'companyApprove']);
    Route::post('/contracts/{contract}/complete', [ContractController::class, 'complete']);
    Route::post('/contracts/{contract}/archive', [ContractController::class, 'archive']);
    Route::post('/contracts/{contract}/clauses', [ContractController::class, 'addClause']);
    Route::put('/contracts/{contract}/clauses/{clause}', [ContractController::class, 'updateClause']);
    Route::delete('/contracts/{contract}/clauses/{clause}', [ContractController::class, 'destroyClause']);

    // Payments
    Route::get('/workspaces/{workspace}/payments', [PaymentController::class, 'index']);
    Route::post('/workspaces/{workspace}/payments', [PaymentController::class, 'store']);
    Route::post('/payments/{payment}/review', [PaymentController::class, 'review']);

    // Approvals
    Route::get('/workspaces/{workspace}/approvals', [ApprovalController::class, 'index']);
    Route::post('/workspaces/{workspace}/approvals', [ApprovalController::class, 'store']);
    Route::get('/approvals/{approval}', [ApprovalController::class, 'show']);
    Route::post('/approvals/{approval}/respond', [ApprovalController::class, 'respond']);

    // Meetings
    Route::get('/workspaces/{workspace}/meetings', [MeetingController::class, 'index']);
    Route::post('/workspaces/{workspace}/meetings', [MeetingController::class, 'store']);

    // Files
    Route::get('/workspaces/{workspace}/files', [FileController::class, 'index']);
    Route::post('/workspaces/{workspace}/files', [FileController::class, 'upload']);
    Route::post('/files/{file}/review', [FileController::class, 'review']);
    Route::post('/workspaces/{workspace}/document-definitions', [FileController::class, 'storeDefinition']);
    Route::delete('/workspaces/{workspace}/document-definitions/{documentDefinition}', [FileController::class, 'destroyDefinition']);

    Route::get('/contracts/{contract}/required-documents', [ContractController::class, 'requiredDocuments']);
    Route::get('/contracts/{contract}/files', [ContractController::class, 'files']);

    // Contract Clause Templates
    Route::get('/contract-clause-templates', [ContractController::class, 'templates']);

    // Audit & Reports
    Route::get('/audit-logs', [AuditController::class, 'index']);
    Route::get('/reports', [AuditController::class, 'reports']);

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::post('/notifications/register-token', [NotificationController::class, 'registerToken']);
    Route::post('/notifications/send-fcm', [NotificationController::class, 'sendFcm']);
});
