<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\CustomerFavoriteFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A product a Customer marked as a favourite (`08` Section 32). Created only
 * by the favourites action, which sets both ids; nothing is mass-assignable
 * from a request.
 *
 * @property string $id
 * @property string $customer_id
 * @property string $product_id
 * @property Carbon $created_at
 */
class CustomerFavorite extends Model
{
    /** @use HasFactory<CustomerFavoriteFactory> */
    use HasFactory;

    use HasUuids;

    public const UPDATED_AT = null;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'customer_id',
        'product_id',
    ];

    /**
     * @return BelongsTo<User, $this>
     */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * @return BelongsTo<Product, $this>
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
