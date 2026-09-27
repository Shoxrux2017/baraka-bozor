<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * A reassignment (`docs/09` section 39): the new Shopper, `shopper_id`, and
 * the assignment the Operator saw and replaces, `replaces_assignment_id`, so
 * a stale or retried reassignment is refused rather than undoing a newer one
 * (`DL-45` (8)).
 */
final class ReassignShopperRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'shopper_id' => ['required', 'string', 'uuid'],
            'replaces_assignment_id' => ['required', 'string', 'uuid'],
        ];
    }

    public function shopperId(): string
    {
        return strtolower((string) $this->validated('shopper_id'));
    }

    public function replacesAssignmentId(): string
    {
        return strtolower((string) $this->validated('replaces_assignment_id'));
    }
}
