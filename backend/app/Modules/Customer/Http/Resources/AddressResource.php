<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Resources;

use App\Models\CustomerAddress;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A delivery address as its owner sees it (`docs/09` section 13).
 * Coordinates are six-decimal strings.
 *
 * @property-read CustomerAddress $resource
 */
final class AddressResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $address = $this->resource;

        return [
            'id' => $address->id,
            'label' => $address->label,
            'latitude' => $address->latitude,
            'longitude' => $address->longitude,
            'street' => $address->street,
            'house' => $address->house,
            'apartment' => $address->apartment,
            'landmark' => $address->landmark,
            'delivery_note' => $address->delivery_note,
            'created_at' => $address->created_at->toIso8601ZuluString(),
            'updated_at' => $address->updated_at->toIso8601ZuluString(),
        ];
    }
}
