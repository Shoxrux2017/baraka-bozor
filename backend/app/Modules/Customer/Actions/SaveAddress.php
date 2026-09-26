<?php

declare(strict_types=1);

namespace App\Modules\Customer\Actions;

use App\Models\CustomerAddress;
use App\Models\User;
use App\Modules\Customer\CustomerAddresses;
use App\Modules\Settings\ServiceAreaPolicy;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Creates, updates and deactivates a Customer's own addresses (`docs/09`
 * section 13, `BR-AREA-001`, `BR-CHK-002`, `DL-23`).
 *
 * A new point, on create or when an update moves it, must lie inside the
 * service area: `422 address_outside_service_area` with both distances, or
 * `409 checkout_configuration_incomplete` while the area is unset (`DL-17`
 * (7)). An update that leaves the point where it is — by omitting it or by
 * sending it back unchanged, as a whole edit form does — is not checked
 * again, so a Customer can still fix a typo in the house number of an
 * address the business has since drawn its circle away from; checkout checks
 * again.
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
            $address = ScopedLookup::lockOrNotFound(CustomerAddresses::own($customer)->whereKey($addressId));
            $address->fill($fields);

            // The `decimal:6` cast compares values, so "41.3" sent back for a
            // stored 41.300000 is no move.
            if ($address->isDirty(['latitude', 'longitude'])) {
                $this->area->assertDeliverable($address->latitude, $address->longitude);
            }

            $address->save();

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
            $address = ScopedLookup::lockOrNotFound(CustomerAddresses::own($customer)->whereKey($addressId));

            $address->is_active = false;
            $address->save();
        });
    }
}
