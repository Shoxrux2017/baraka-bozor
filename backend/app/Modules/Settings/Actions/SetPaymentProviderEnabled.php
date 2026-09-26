<?php

declare(strict_types=1);

namespace App\Modules\Settings\Actions;

use App\Models\Enums\PaymentProvider;
use App\Models\PaymentProviderSetting;
use App\Models\User;

/**
 * Turns one provider on or off for new online payments (`BR-SET-004`). The
 * four rows exist from their migration, so this is always an update; an
 * unchanged value still records who last saved it.
 */
final class SetPaymentProviderEnabled
{
    public function __invoke(User $admin, PaymentProvider $provider, bool $enabled): PaymentProviderSetting
    {
        $setting = PaymentProviderSetting::query()->findOrFail($provider->value);

        $setting->is_enabled = $enabled;
        $setting->updated_by_user_id = $admin->id;
        $setting->save();

        return $setting;
    }
}
