<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\CustomerAddressFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A Customer's delivery address (`08` Section 5).
 *
 * `customer_id` and `is_active` are outside `$fillable`: the owner is the
 * authenticated Customer, never a request field, and an address is deactivated
 * by the delete action rather than by a flag in an update body.
 *
 * Coordinates are strings of six decimals, as the API sends and returns them
 * (`09` Section 13); nothing here turns them into floating point.
 *
 * @property string $id
 * @property string $customer_id
 * @property string|null $label
 * @property string $latitude
 * @property string $longitude
 * @property string $street
 * @property string $house
 * @property string|null $apartment
 * @property string|null $landmark
 * @property string|null $delivery_note
 * @property bool $is_active
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class CustomerAddress extends Model
{
    /** @use HasFactory<CustomerAddressFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'label',
        'latitude',
        'longitude',
        'street',
        'house',
        'apartment',
        'landmark',
        'delivery_note',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:6',
            'longitude' => 'decimal:6',
            'is_active' => 'boolean',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }
}
