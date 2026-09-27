<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\SubstitutionPolicy;
use App\Modules\Orders\Actions\ChangeCart;
use Illuminate\Validation\Rule;

/**
 * An order edit (`docs/09` section 21): the whole item list — at least one
 * line, at most 100, each product once — and the delivery wish, which must be
 * sent, `null` to clear it, because the request states the order as the
 * Customer wants it. A line's note and rule default to none and
 * `allow_similar_substitution` when left out; its quantity is checked against
 * its unit by the action.
 */
final class EditOrderItemsRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'list', 'min:1', 'max:'.ChangeCart::MAX_LINES],
            'items.*' => ['required', 'array'],
            'items.*.product_id' => ['required', 'string', 'uuid', 'distinct'],
            'items.*.quantity' => ['required', 'string'],
            'items.*.customer_note' => ['sometimes', 'nullable', 'string', 'max:300'],
            'items.*.substitution_policy' => ['sometimes', 'required', 'string', Rule::enum(SubstitutionPolicy::class)],
            'delivery_time_note' => ['present', 'nullable', 'string', 'max:160'],
        ];
    }
}
