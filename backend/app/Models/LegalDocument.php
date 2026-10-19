<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One edition of a legal document (`08` Section 34). Rows are only ever
 * appended: the newest row of a kind and language is in force, a null `body`
 * is an unpublished document. There is no `updated_at`.
 *
 * @property string $id
 * @property string $kind
 * @property string $language
 * @property string|null $body
 * @property string $created_by_user_id
 * @property Carbon $created_at
 */
class LegalDocument extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    /**
     * @var list<string>
     */
    protected $fillable = [];

    /**
     * @return BelongsTo<User, $this>
     */
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }
}
