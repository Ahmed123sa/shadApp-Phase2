<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class ChatMessage extends Model
{
    use HasFactory;

    protected $fillable = [
        'workspace_id', 'sender_type', 'sender_id', 'message',
        'type', 'file_url', 'requires_action', 'contract_id', 'approval_id',
        'action_taken', 'action_result', 'responded_at', 'read_at',
    ];

    protected function casts(): array
    {
        return [
            'requires_action' => 'boolean',
            'action_taken' => 'boolean',
            'responded_at' => 'datetime',
            'read_at' => 'datetime',
        ];
    }

    public function workspace(): BelongsTo
    {
        return $this->belongsTo(Workspace::class);
    }

    public function sender()
    {
        return $this->morphTo();
    }

    public function approval(): BelongsTo
    {
        return $this->belongsTo(Approval::class);
    }
}
