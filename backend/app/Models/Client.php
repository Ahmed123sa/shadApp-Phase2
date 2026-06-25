<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Notifications\Notifiable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Laravel\Sanctum\HasApiTokens;

class Client extends Model
{
    use HasFactory, Notifiable, HasApiTokens;

    protected $fillable = [
        'company_name', 'contact_person', 'email', 'phone', 'password',
        'manager_id', 'status', 'notes', 'country', 'industry', 'client_type',
        'contract_value', 'payment_status', 'signature_data', 'signed_at',
        'avatar_url',
    ];

    protected $hidden = ['password'];

    protected $appends = ['name'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'contract_value' => 'decimal:2',
            'signed_at' => 'datetime',
        ];
    }

    public function manager(): BelongsTo
    {
        return $this->belongsTo(User::class, 'manager_id');
    }

    public function workspace(): HasOne
    {
        return $this->hasOne(Workspace::class);
    }

    public function subUsers(): HasMany
    {
        return $this->hasMany(SubUser::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function getNameAttribute(): ?string
    {
        return $this->contact_person;
    }
}
