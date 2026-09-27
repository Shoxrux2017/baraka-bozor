<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\IdempotencyState;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A persisted idempotency key (`08` Section 27, `DL-37` (5)). Written only by
 * the idempotency store, which owns the lease, the attempt token and the
 * replay; nothing is mass-assignable.
 *
 * @property string $id
 * @property string $actor_user_id
 * @property string $operation
 * @property string $idempotency_key
 * @property string $request_hash
 * @property IdempotencyState $state
 * @property string $attempt_token
 * @property Carbon $lease_expires_at
 * @property string|null $resource_type
 * @property string|null $resource_id
 * @property Carbon $created_at
 * @property Carbon|null $completed_at
 */
class IdempotencyKey extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    /**
     * @var list<string>
     */
    protected $fillable = [];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'state' => IdempotencyState::class,
            'lease_expires_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }
}
