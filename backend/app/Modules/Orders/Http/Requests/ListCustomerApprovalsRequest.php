<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Models\Enums\ApprovalStatus;
use Illuminate\Validation\Rule;

/**
 * `GET /customer/approvals`: the page, its size and a status to narrow to —
 * `pending` for the questions still waiting, which leaves out any past its
 * expiry (`DL-54` (8)).
 */
final class ListCustomerApprovalsRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'status' => ['sometimes', 'nullable', 'string', Rule::enum(ApprovalStatus::class)],
        ];
    }

    public function status(): ?ApprovalStatus
    {
        $status = $this->text('status');

        return $status === null ? null : ApprovalStatus::from($status);
    }
}
