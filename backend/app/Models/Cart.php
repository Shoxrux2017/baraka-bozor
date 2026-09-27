<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\CartStatus;
use Database\Factories\CartFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A Customer's cart (`08` Section 9). One is `active` at a time
 * (`BR-CART-001`); an order converts it and a new one takes its place in the
 * same transaction (`BR-CHK-008`).
 *
 * Nothing here is mass-assignable: the owner and the status are the actions'
 * to decide, never input's.
 *
 * @property string $id
 * @property string $customer_id
 * @property CartStatus $status
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Cart extends Model
{
    /** @use HasFactory<CartFactory> */
    use HasFactory;

    use HasUuids;

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
            'status' => CartStatus::class,
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * @return HasMany<CartItem, $this>
     */
    public function items(): HasMany
    {
        return $this->hasMany(CartItem::class);
    }
}
