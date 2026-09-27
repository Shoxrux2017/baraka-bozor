<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A Shopper in the Operator's picker (`docs/09` section 39): who, the phone
 * to call, and how many orders the Shopper holds now.
 *
 * Expects `current_assignment_count` from `ShopperPicker`.
 *
 * @property-read User $resource
 */
final class ShopperChoiceResource extends JsonResource
{
    public function __construct(User $shopper)
    {
        parent::__construct($shopper);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $shopper = $this->resource;

        return [
            'id' => $shopper->id,
            'full_name' => $shopper->full_name,
            'phone' => $shopper->phone,
            'current_assignment_count' => (int) $shopper->getAttribute('current_assignment_count'),
        ];
    }
}
