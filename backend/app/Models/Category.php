<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\CategoryFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A catalog category (`08` Section 6): flat, bilingual, archived rather than
 * deleted.
 *
 * `is_active`, `archived_at` and `created_by_user_id` are outside `$fillable`.
 * Hiding (`is_active`) is part of the write body (`09` Section 15), but the
 * two flags move under a rule `fill()` cannot enforce — an archived category
 * is never active (`categories_archived_inactive_check`) — so the catalog
 * actions assign both explicitly; archiving has its own endpoint, and the
 * creator is the authenticated Admin.
 *
 * @property string $id
 * @property string $name_uz
 * @property string $name_ru
 * @property string|null $description_uz
 * @property string|null $description_ru
 * @property int $sort_order
 * @property bool $is_active
 * @property Carbon|null $archived_at
 * @property string $created_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Category extends Model
{
    /** @use HasFactory<CategoryFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name_uz',
        'name_ru',
        'description_uz',
        'description_ru',
        'sort_order',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
            'is_active' => 'boolean',
            'archived_at' => 'datetime',
        ];
    }

    /**
     * @return HasMany<Product, $this>
     */
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
