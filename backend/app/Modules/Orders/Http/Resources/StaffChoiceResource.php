<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A Shopper or a Courier in the Operator's picker (`docs/09` section 39):
 * who, the phone to call, and how many orders they hold now.
 *
 * Expects `current_assignment_count` from `StaffPicker`.
 *
 * @property-read User $resource
 */
final class StaffChoiceResource extends JsonResource
{
    public function __construct(User $staff)
    {
        parent::__construct($staff);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $staff = $this->resource;

        return [
            'id' => $staff->id,
            'full_name' => $staff->full_name,
            'phone' => $staff->phone,
            'current_assignment_count' => (int) $staff->getAttribute('current_assignment_count'),
        ];
    }
}
