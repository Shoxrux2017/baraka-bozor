<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\PushPlatform;
use Database\Factories\PushDeviceFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A push token registered by one account on one device (`08` Section 25).
 * The account is the authenticated caller, never a request field, so
 * `user_id` is outside `$fillable`; revocation is an action, not a flag.
 *
 * @property string $id
 * @property string $user_id
 * @property PushPlatform $platform
 * @property string $push_token
 * @property Carbon|null $last_seen_at
 * @property Carbon|null $revoked_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class PushDevice extends Model
{
    /** @use HasFactory<PushDeviceFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'platform',
        'push_token',
    ];

    /**
     * The token addresses one phone; no serialisation of the model should
     * carry it (`DL-26` (2)).
     *
     * @var list<string>
     */
    protected $hidden = [
        'push_token',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'platform' => PushPlatform::class,
            'last_seen_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
