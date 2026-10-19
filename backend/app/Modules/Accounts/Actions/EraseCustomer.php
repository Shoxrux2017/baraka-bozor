<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\User;
use App\Modules\Accounts\UnfinishedOrders;
use App\Modules\Orders\CustomerCart;
use Illuminate\Support\Facades\DB;

/**
 * Erases a Customer's personal data and frees the phone (`BR-ROLE-013`,
 * `DL-94` item 4).
 *
 * The user row stays as `deleted` with no phone or name, because orders,
 * payments, assignments and history reference it. Only the personal fields
 * listed here change; an order's status, lines, quantities, prices, totals,
 * payments, approvals and history events are never touched.
 *
 * Order placement takes the Customer's cart lock first; so does this, then the
 * user row, and the unfinished-order check is made again under them. An order
 * is therefore either placed before the erasure takes the lock, and refuses it,
 * or after it, and finds the tokens gone.
 */
final class EraseCustomer
{
    /** Keys of an edit entry's `details` that carry the Customer's free text. */
    private const NOTE_KEYS = ['delivery_time_note', 'customer_note'];

    /**
     * @throws ApiException `account_has_unfinished_orders` (409), or not found
     *                      for an account that is not an erasable Customer
     */
    public function erase(User $customer, User $actor): void
    {
        DB::transaction(function () use ($customer, $actor): void {
            CustomerCart::lock($customer);

            $locked = User::query()->whereKey($customer->id)->lockForUpdate()->first();

            if ($locked === null || $locked->role !== Role::Customer || $locked->status === UserStatus::Deleted) {
                throw ApiException::notFound();
            }

            $unfinished = UnfinishedOrders::oldest($locked);

            if ($unfinished !== null) {
                throw ApiException::conflict('account_has_unfinished_orders', [
                    'order_id' => $unfinished->id,
                    'order_number' => $unfinished->order_number,
                ]);
            }

            $this->eraseRows($locked, $actor);
        });

        $customer->refresh();
    }

    private function eraseRows(User $customer, User $actor): void
    {
        $phone = $customer->phone;
        $orderIds = Order::query()->where('customer_id', $customer->id)->select('id');

        DB::table('customer_addresses')->where('customer_id', $customer->id)->delete();
        DB::table('customer_favorites')->where('customer_id', $customer->id)->delete();
        DB::table('push_devices')->where('user_id', $customer->id)->delete();
        DB::table('idempotency_keys')->where('actor_user_id', $customer->id)->delete();
        $customer->tokens()->delete();

        if ($phone !== null) {
            DB::table('customer_otp_challenges')->where('phone', $phone)->delete();
        }

        $cartIds = DB::table('carts')->where('customer_id', $customer->id)->select('id');
        DB::table('cart_items')->whereIn('cart_id', $cartIds)->update(['customer_note' => null]);
        $activeCartIds = DB::table('carts')->where('customer_id', $customer->id)->where('status', 'active')->select('id');
        DB::table('cart_items')->whereIn('cart_id', $activeCartIds)->delete();

        DB::table('orders')->where('customer_id', $customer->id)->update([
            'recipient_name_snapshot' => null,
            'recipient_phone_snapshot' => null,
            'latitude_snapshot' => null,
            'longitude_snapshot' => null,
            'street_snapshot' => null,
            'house_snapshot' => null,
            'apartment_snapshot' => null,
            'landmark_snapshot' => null,
            'delivery_note_snapshot' => null,
            'delivery_time_note' => null,
            'customer_erased_at' => now(),
        ]);
        DB::table('order_items')->whereIn('order_id', $orderIds)->update(['customer_note_snapshot' => null]);
        DB::table('order_ratings')->whereIn('order_id', $orderIds)->update(['comment' => null]);
        DB::table('order_cancellation_requests')->where('requested_by_user_id', $customer->id)->update(['reason' => null]);

        // The history table refuses every update except the one this
        // transaction opens: `note` and `details` of a row, nothing else.
        DB::statement("select set_config('app.customer_erasure', 'on', true)");
        DB::table('order_history')->where('actor_user_id', $customer->id)->update(['note' => null]);

        $this->stripEditNotes($customer);

        $customer->forceFill([
            'status' => UserStatus::Deleted,
            'phone' => null,
            'full_name' => null,
            'last_login_at' => null,
            'deleted_at' => now(),
            'deleted_by_user_id' => $actor->id,
        ])->save();
    }

    /**
     * The Customer's own edit entries record the delivery wish and the line
     * notes they changed; the ids, quantities and policies stay.
     */
    private function stripEditNotes(User $customer): void
    {
        $rows = DB::table('order_history')
            ->where('actor_user_id', $customer->id)
            ->where('event_type', OrderHistoryEvent::Edited->value)
            ->whereNotNull('details')
            ->select(['id', 'details'])
            ->get();

        foreach ($rows as $row) {
            $details = json_decode((string) $row->details, true, 512, JSON_THROW_ON_ERROR);

            if (! is_array($details)) {
                continue;
            }

            DB::table('order_history')->where('id', $row->id)->update([
                'details' => json_encode(self::withoutNotes($details), JSON_THROW_ON_ERROR),
            ]);
        }
    }

    /**
     * @param  array<mixed>  $value
     * @return array<mixed>
     */
    private static function withoutNotes(array $value): array
    {
        $kept = [];

        foreach ($value as $key => $item) {
            if (is_string($key) && in_array($key, self::NOTE_KEYS, true)) {
                continue;
            }

            $kept[$key] = is_array($item) ? self::withoutNotes($item) : $item;
        }

        return $kept;
    }
}
