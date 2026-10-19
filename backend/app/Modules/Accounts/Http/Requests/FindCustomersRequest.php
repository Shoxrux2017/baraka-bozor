<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Http\Requests;

use App\Modules\Auth\LoginCodePolicy;
use Illuminate\Foundation\Http\FormRequest;

/**
 * The `phone` query of the Admin's customer search (`docs/09` Section 66).
 */
final class FindCustomersRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:'.LoginCodePolicy::PHONE_PATTERN],
        ];
    }
}
