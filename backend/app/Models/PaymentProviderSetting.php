<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\PaymentProvider;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Whether one online payment provider may take new payments (`08` Section 12,
 * `BR-SET-004`). Keyed by the provider; the four rows exist from the
 * migration, so nothing creates or deletes one.
 *
 * @property PaymentProvider $provider
 * @property bool $is_enabled
 * @property string|null $updated_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class PaymentProviderSetting extends Model
{
    protected $table = 'payment_provider_settings';

    protected $primaryKey = 'provider';

    public $incrementing = false;

    protected $keyType = 'string';

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
            'provider' => PaymentProvider::class,
            'is_enabled' => 'boolean',
        ];
    }
}
