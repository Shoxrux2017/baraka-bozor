<?php

declare(strict_types=1);

namespace App\Modules\Staff\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A staff account as Admin manages it (`docs/09` section 43). The password
 * hash, the creator and the interface language are not part of it.
 *
 * @property-read User $resource
 */
final class StaffResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $staff = $this->resource;

        return [
            'id' => $staff->id,
            'role' => $staff->role->value,
            'phone' => $staff->phone,
            'full_name' => $staff->full_name,
            'status' => $staff->status->value,
            'must_change_password' => $staff->must_change_password,
            'last_login_at' => $staff->last_login_at?->toIso8601ZuluString(),
            'blocked_at' => $staff->blocked_at?->toIso8601ZuluString(),
            'created_at' => $staff->created_at->toIso8601ZuluString(),
            'updated_at' => $staff->updated_at->toIso8601ZuluString(),
        ];
    }
}
