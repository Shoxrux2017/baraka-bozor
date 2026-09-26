<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Enums\PaymentProvider;
use App\Models\PaymentProviderSetting;
use App\Models\User;
use App\Modules\Settings\Actions\SetPaymentProviderEnabled;
use App\Modules\Settings\Http\Requests\UpdatePaymentProviderSettingRequest;
use App\Modules\Settings\Http\Resources\PaymentProviderSettingResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * `GET /admin/settings/payment-providers` and
 * `PATCH /admin/settings/payment-providers/{provider}` (`docs/09` section 44).
 *
 * The list is the fixed four in the order the interview names them, not
 * paginated: it can never grow without a migration (`DL-19`).
 */
final class PaymentProviderSettingsController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        $byProvider = PaymentProviderSetting::query()->get()->keyBy(
            static fn (PaymentProviderSetting $setting): string => $setting->provider
        );

        $ordered = array_values(array_filter(array_map(
            static fn (PaymentProvider $provider): ?PaymentProviderSetting => $byProvider->get($provider->value),
            PaymentProvider::cases()
        )));

        return PaymentProviderSettingResource::collection($ordered);
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
