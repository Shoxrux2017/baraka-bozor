<?php

declare(strict_types=1);

namespace App\Modules\Staff\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use Illuminate\Validation\Rule;

/**
 * `GET /admin/staff?role=&status=&page=&per_page=` (`docs/09` section 43).
 */
final class ListStaffRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'role' => ['sometimes', 'nullable', 'string', Rule::enum(Role::class)->except([Role::Customer])],
            'status' => ['sometimes', 'nullable', 'string', Rule::enum(UserStatus::class)],
        ];
    }

    public function role(): ?Role
    {
        $role = $this->text('role');

        return $role === null ? null : Role::from($role);
    }

    public function status(): ?UserStatus
    {
        $status = $this->text('status');

        return $status === null ? null : UserStatus::from($status);
    }
}
