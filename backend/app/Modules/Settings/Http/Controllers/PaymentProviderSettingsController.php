<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Enums\PaymentProvider;
use App\Models\PaymentProviderSetting;
use App\Models\User;
use App\Modules\Settings\Actions\SetPaymentProviderEnabled;
use App\Modules\Settings\Http\Requests\UpdatePaymentProviderSettingRequest;
use App\Modules\Settings\Http\Resources\PaymentProviderSettingResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;

/**
 * `GET /admin/settings/payment-providers` and
 * `PATCH /admin/settings/payment-providers/{provider}` (`docs/09` section 44).
 *
 * The list is the fixed four in the order the interview names them, answered
 * in the one collection envelope of `docs/09` section 2 as a single page, so
 * the panel parses every list the same way (`DL-19`).
 */
final class PaymentProviderSettingsController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $settings = PaymentProviderSetting::inProviderOrder();
        $count = count($settings);

        return PaginatedResponse::of(
            new LengthAwarePaginator($settings, $count, max($count, 1), 1),
            static fn (PaymentProviderSetting $setting): array => (new PaymentProviderSettingResource($setting))->resolve($request),
        );
    }

    public function update(
        UpdatePaymentProviderSettingRequest $request,
        string $provider,
        SetPaymentProviderEnabled $setEnabled,
    ): PaymentProviderSettingResource {
        // The route pattern admits only the four values, so this cannot fail.
        $known = PaymentProvider::from($provider);

        return new PaymentProviderSettingResource(
            $setEnabled($this->admin($request), $known, (bool) $request->validated('is_enabled'))
        );
    }

    private function admin(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
