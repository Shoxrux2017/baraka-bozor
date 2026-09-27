<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\SubstitutionPolicy;
use Database\Factories\CartItemFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A cart line (`08` Section 10): one product, a quantity as a decimal string,
 * a note and a substitution rule. The price is not here: the cart shows the
 * current customer price on every read (`BR-CART-003`).
 *
 * The cart it belongs to is not mass-assignable; the action that adds a line
 * sets it from the Customer's own active cart.
 *
 * @property string $id
 * @property string $cart_id
 * @property string $product_id
 * @property string $quantity
 * @property string|null $customer_note
 * @property SubstitutionPolicy $substitution_policy
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class CartItem extends Model
{
    /** @use HasFactory<CartItemFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'product_id',
        'quantity',
        'customer_note',
        'substitution_policy',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'substitution_policy' => SubstitutionPolicy::class,
        ];
    }

    /**
     * @return BelongsTo<Cart, $this>
     */
    public function cart(): BelongsTo
    {
        return $this->belongsTo(Cart::class);
    }

    /**
     * @return BelongsTo<Product, $this>
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
