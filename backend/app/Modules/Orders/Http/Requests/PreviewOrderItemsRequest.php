<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

/**
 * A preview of an order edit (`docs/09` section 21, `DL-132` (1)): the edit's
 * `items` rules exactly, and no `delivery_time_note`, which the strict shape
 * then refuses — the wish changes no sum.
 */
final class PreviewOrderItemsRequest extends EditOrderItemsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return array_diff_key(parent::rules(), ['delivery_time_note' => true]);
    }
}
