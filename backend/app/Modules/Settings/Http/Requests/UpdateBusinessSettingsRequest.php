<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\ServiceFeeMode;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * The shape of each business setting (`docs/08-database.md` section 11,
 * `BR-SET-001`), any subset of them per request.
 *
 * Money is an integer UZS and nothing else; percentages, coordinates and the
 * radius are decimal strings (`docs/09` section 1), never JSON numbers, so a
 * value never passes through binary floating point on the way in. The rules
 * that span fields — the service-fee mode against its two values, the
 * working-hours pair, the centre pair — are checked by the action against the
 * merged, locked row, because a subset alone cannot tell.
 */
final class UpdateBusinessSettingsRequest extends StrictFormRequest
{
    /** A `numeric(5,2)` percentage as a decimal string. */
    private const PERCENT = 'regex:/^\d{1,3}(\.\d{1,2})?\z/';

    /** An amount of UZS no setting could sensibly exceed. */
    private const MAX_UZS = 1_000_000_000;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'markup_percent' => ['sometimes', 'required', 'string', self::PERCENT],
            'service_fee_mode' => ['sometimes', 'required', 'string', Rule::enum(ServiceFeeMode::class)],
            'service_fee_fixed_uzs' => ['sometimes', 'nullable', 'integer:strict', 'min:0', 'max:'.self::MAX_UZS],
            'service_fee_percent' => ['sometimes', 'nullable', 'string', self::PERCENT],
            'delivery_fee_uzs' => ['sometimes', 'nullable', 'integer:strict', 'min:0', 'max:'.self::MAX_UZS],
            'minimum_order_uzs' => ['sometimes', 'nullable', 'integer:strict', 'min:0', 'max:'.self::MAX_UZS],
            'price_tolerance_percent' => ['sometimes', 'required', 'string', self::PERCENT],
            'opens_at' => ['sometimes', 'nullable', 'string', 'date_format:H:i'],
            'closes_at' => ['sometimes', 'nullable', 'string', 'date_format:H:i'],
            'service_centre_latitude' => [
                'sometimes', 'nullable', 'string', 'regex:/^-?\d{1,2}(\.\d{1,6})?\z/', 'numeric', 'between:-90,90',
            ],
            'service_centre_longitude' => [
                'sometimes', 'nullable', 'string', 'regex:/^-?\d{1,3}(\.\d{1,6})?\z/', 'numeric', 'between:-180,180',
            ],
            'service_radius_km' => [
                'sometimes', 'nullable', 'string', 'regex:/^\d{1,4}(\.\d{1,2})?\z/', 'numeric', 'gt:0',
            ],
            'delivery_delay_threshold_minutes' => ['sometimes', 'required', 'integer:strict', 'min:1', 'max:1440'],
        ];
    }

    /**
     * A body that names no setting changes nothing, and saving it would still
     * record the Admin as the last to change the settings; it is refused. This
     * also catches a body the JSON decoder could not read, which the framework
     * hands over as empty.
     *
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                if ($this->all() === []) {
                    $validator->errors()->add('body', 'Name at least one setting to change.');
                }
            },
        ];
    }
}
