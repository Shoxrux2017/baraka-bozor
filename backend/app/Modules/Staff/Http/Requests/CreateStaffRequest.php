<?php

declare(strict_types=1);

namespace App\Modules\Staff\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\Role;
use Illuminate\Validation\Rule;

/**
 * A new staff account (`docs/09` section 43): a name of 1 to 120 characters
 * after trimming, a phone in the `+998` form the database holds, and any
 * role but Customer — a Customer signs in with a login code and is never
 * created by an Admin (`BR-ROLE-003`).
 */
final class CreateStaffRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'regex:/^\+998[0-9]{9}\z/'],
            'role' => ['required', 'string', Rule::enum(Role::class)->except([Role::Customer])],
        ];
    }

    public function fullName(): string
    {
        return (string) $this->validated('full_name');
    }

    public function phone(): string
    {
        return (string) $this->validated('phone');
    }

    public function role(): Role
    {
        return Role::from((string) $this->validated('role'));
    }
}
