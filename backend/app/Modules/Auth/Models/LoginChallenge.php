<?php

declare(strict_types=1);

namespace App\Modules\Auth\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * One issued Customer login code — the `customer_otp_challenges` table of
 * `docs/08-database.md` Section 4.
 *
 * Only the hash of the code is stored. A challenge is created once and then
 * closed by `consumed_at` (a successful verification) or `invalidated_at` (a
 * newer challenge for the same phone); it has no `updated_at`.
 *
 * @property string $id
 * @property string $phone
 * @property string $purpose
 * @property string $code_hash
 * @property int $failed_attempts
 * @property string $channel
 * @property Carbon $expires_at
 * @property Carbon|null $consumed_at
 * @property Carbon|null $invalidated_at
 * @property Carbon $created_at
 */
final class LoginChallenge extends Model
{
    use HasUuids;

    public const PURPOSE_CUSTOMER_LOGIN = 'customer_login';

    protected $table = 'customer_otp_challenges';

    public $timestamps = false;

    /** @var list<string> */
    protected $guarded = ['*'];

    /** @var list<string> */
    protected $hidden = ['code_hash'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'failed_attempts' => 'integer',
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'invalidated_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    /**
     * Challenges still open for a phone: not consumed, not invalidated.
     *
     * @param  Builder<LoginChallenge>  $query
     * @return Builder<LoginChallenge>
     */
    public function scopeOpenFor(Builder $query, string $phone): Builder
    {
        return $query
            ->where('phone', $phone)
            ->where('purpose', self::PURPOSE_CUSTOMER_LOGIN)
            ->whereNull('consumed_at')
            ->whereNull('invalidated_at');
    }

    public function isExpired(): bool
    {
        return $this->expires_at->lte(Carbon::now());
    }
}
