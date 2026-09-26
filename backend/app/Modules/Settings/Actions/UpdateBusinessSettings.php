<?php

declare(strict_types=1);

namespace App\Modules\Settings\Actions;

use App\Models\BusinessSettings;
use App\Models\Enums\ServiceFeeMode;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Applies any subset of the business settings (`docs/09` section 44).
 *
 * The singleton row is locked, the subset merged into it, and the rules that
 * span fields checked against the merged result, so two Admins saving at once
 * cannot together produce a row neither of them could have saved alone. A
 * cross-field refusal is a `validation_failed` on the field that has to change:
 * the value of the service-fee mode not chosen, the missing half of the
 * working hours or of the centre.
 *
 * Settings changes never touch existing orders (`BR-SET-003`); orders snapshot
 * what they need when they are created.
 */
final class UpdateBusinessSettings
{
    /**
     * @param  array<string, mixed>  $changes  the validated subset
     */
    public function __invoke(User $admin, array $changes): BusinessSettings
    {
        return DB::transaction(function () use ($admin, $changes): BusinessSettings {
            $settings = BusinessSettings::query()->lockForUpdate()->findOrFail(BusinessSettings::SINGLETON_ID);

            $settings->forceFill($changes);

            $this->assertConsistent($settings);

            $settings->updated_by_user_id = $admin->id;
            $settings->save();

            return $settings->refresh();
        });
    }

    private function assertConsistent(BusinessSettings $settings): void
    {
        $errors = [];

        if ($settings->service_fee_mode === ServiceFeeMode::Fixed && $settings->service_fee_percent !== null) {
            $errors['service_fee_percent'] = 'Must be null while service_fee_mode is fixed.';
        }

        if ($settings->service_fee_mode === ServiceFeeMode::Percentage && $settings->service_fee_fixed_uzs !== null) {
            $errors['service_fee_fixed_uzs'] = 'Must be null while service_fee_mode is percentage.';
        }

        if (($settings->opens_at === null) !== ($settings->closes_at === null)) {
            $errors[$settings->opens_at === null ? 'opens_at' : 'closes_at'] = 'Working hours need both opens_at and closes_at.';
        } elseif ($settings->opens_at !== null && $this->minutes($settings->opens_at) === $this->minutes((string) $settings->closes_at)) {
            $errors['closes_at'] = 'Must differ from opens_at.';
        }

        if (($settings->service_centre_latitude === null) !== ($settings->service_centre_longitude === null)) {
            $missing = $settings->service_centre_latitude === null ? 'service_centre_latitude' : 'service_centre_longitude';
            $errors[$missing] = 'The service-area centre needs both a latitude and a longitude.';
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }
    }

    /**
     * Minutes since midnight of an `H:i` or `H:i:s` time, so `08:00` from the
     * request and `08:00:00` from the column compare equal.
     */
    private function minutes(string $time): int
    {
        [$hours, $minutes] = array_map('intval', explode(':', $time));

        return $hours * 60 + $minutes;
    }
}
