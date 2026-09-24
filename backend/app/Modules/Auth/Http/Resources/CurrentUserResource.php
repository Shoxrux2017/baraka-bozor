<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The identity object of `docs/09-api-contracts.md` Section 7 and Section 9.
 *
 * @property-read User $resource
 */
final class CurrentUserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource->id,
            'role' => $this->resource->role->value,
            'phone' => $this->resource->phone,
            'full_name' => $this->resource->full_name,
            'status' => $this->resource->status->value,
            'must_change_password' => $this->resource->must_change_password,
            'preferred_language' => $this->resource->preferred_language,
        ];
    }
}
