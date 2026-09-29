<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Models\Enums\CancellationRequestStatus;
use Illuminate\Validation\Rule;

/**
 * `GET /operations/cancellation-requests` (`docs/09` section 40): the page,
 * and a `status` to narrow it to.
 */
final class ListCancellationRequestsRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'status' => ['sometimes', 'nullable', 'string', Rule::enum(CancellationRequestStatus::class)],
        ];
    }

    public function status(): ?CancellationRequestStatus
    {
        $value = $this->text('status');

        return $value === null ? null : CancellationRequestStatus::from($value);
    }
}
