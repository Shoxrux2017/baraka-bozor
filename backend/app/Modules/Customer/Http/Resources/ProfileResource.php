<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The Customer's profile (`docs/09` section 12): the phone they sign in
 * with, the name checkout needs, and the language push texts use.
 *
 * @property-read User $resource
 */
final class ProfileResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource->id,
            'phone' => $this->resource->phone,
            'full_name' => $this->resource->full_name,
            'preferred_language' => $this->resource->preferred_language,
        ];
    }
}
