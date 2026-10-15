<?php

declare(strict_types=1);

namespace App\Modules\Auth\Models;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One staff password step — the `staff_login_steps` table (`DL-77`).
 *
 * Issued when a Customer login code is verified for a phone that also holds a
 * Shopper or Courier account; redeemed once with that account's password.
 * Only the SHA-256 of the token is stored.
 *
 * @property string $id
 * @property string $staff_user_id
 * @property string $token_hash
 * @property CarbonImmutable $expires_at
 * @property CarbonImmutable|null $consumed_at
 * @property int $failed_attempts
 */
final class StaffLoginStep extends Model
{
    use HasUuids;

    public const TTL_SECONDS = 300;

    public const MAX_FAILED_ATTEMPTS = 5;

    protected $table = 'staff_login_steps';

    /** @var list<string> */
    protected $guarded = ['*'];

    /** @var list<string> */
    protected $hidden = ['token_hash'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'failed_attempts' => 'integer',
            'expires_at' => 'immutable_datetime',
            'consumed_at' => 'immutable_datetime',
        ];
    }

    public function isExpired(): bool
    {
        return $this->expires_at->lte(Carbon::now());
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function staff(): BelongsTo
    {
        return $this->belongsTo(User::class, 'staff_user_id');
    }
}
