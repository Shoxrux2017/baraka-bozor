<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\PushPlatform;
use Illuminate\Validation\Rule;

/**
 * A push token and the platform that issued it (`docs/09` section 27). The
 * token is opaque to the backend; it is trimmed and must then hold 1 to 512
 * characters, the column's size (`DL-18` (4)).
 */
final class RegisterPushDeviceRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'platform' => ['required', 'string', Rule::enum(PushPlatform::class)],
            'token' => ['required', 'string', 'max:512'],
        ];
    }

    public function platform(): PushPlatform
    {
        return PushPlatform::from((string) $this->validated('platform'));
    }

    public function token(): string
    {
        return (string) $this->validated('token');
    }
}
