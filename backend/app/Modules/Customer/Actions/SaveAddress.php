<?php

declare(strict_types=1);

namespace App\Modules\Customer\Actions;

use App\Models\CustomerAddress;
use App\Models\User;
use App\Modules\Settings\ServiceAreaPolicy;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Creates and updates a Customer's own addresses (`docs/09` section 13,
 * `BR-AREA-001`, `BR-CHK-002`).
 *
 * A new point, on create or when an update moves it, must lie inside the
 * service area: `422 address_outside_service_area` with both distances, or
 * `409 checkout_configuration_incomplete` while the area is unset (`DL-17`
 * (7)). An update that leaves the point where it is does not re-check it, so
 * a Customer can still fix a typo in the house number of an address the
 * business has since drawn its circle away from; checkout checks again.
 */
final class SaveAddress
{
    public function __construct(private readonly ServiceAreaPolicy $area) {}

    /**
     * @param  array<string, mixed>  $fields
     */
    public function create(User $customer, array $fields): CustomerAddress
    {
        $this->area->assertDeliverable((string) $fields['latitude'], (string) $fields['longitude']);

        $address = new CustomerAddress;
        $address->customer_id = $customer->id;
        $address->fill($fields)->save();

        return $address->refresh();
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public function update(User $customer, string $addressId, array $fields): CustomerAddress
    {
        return DB::transaction(function () use ($customer, $addressId, $fields): CustomerAddress {
            // The address is found first, so a foreign or missing id is the
            // scope-safe 404 whatever point the body carries.
            $address = ScopedLookup::lockOrNotFound(self::own($customer)->whereKey($addressId));

            if (array_key_exists('latitude', $fields)) {
                $this->area->assertDeliverable((string) $fields['latitude'], (string) $fields['longitude']);
            }

            $address->fill($fields)->save();

            return $address->refresh();
        });
    }

    /**
     * Deletion always deactivates (`DL-17` (6)); the address then no longer
     * exists for the Customer, so a second delete is the scope-safe `404`.
     */
    public function deactivate(User $customer, string $addressId): void
    {
        DB::transaction(function () use ($customer, $addressId): void {
            $address = ScopedLookup::lockOrNotFound(self::own($customer)->whereKey($addressId));

            $address->is_active = false;
            $address->save();
        });
    }

    /**
     * The Customer's own active addresses: the only ones that exist for them.
     *
     * @return Builder<CustomerAddress>
     */
    public static function own(User $customer): Builder
    {
        return CustomerAddress::query()
            ->where('customer_id', $customer->id)
            ->where('is_active', true);
    }
}
