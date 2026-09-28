<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `payments`, as `docs/08-database.md` Section 21 names it (`DL-54` (2)): one
 * live payment per order, cash only ever paid and recorded by the Courier
 * (`BR-PAY-003`), online never recorded by a person (`BR-PAY-004`).
 *
 * Each check is proven by a row only it refuses; PostgreSQL evaluates checks
 * in name order, so such a row satisfies every check named before it.
 */
final class PaymentsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'payments';

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->order = Order::factory()->onTheWay()->create();
    }

    /**
     * The cash a Courier records at handover.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function cash(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => $this->order->id,
            'method' => 'cash',
            'provider' => null,
            'amount_uzs' => 120000,
            'status' => 'paid',
            'paid_at' => now(),
            'recorded_by_user_id' => User::factory()->role(Role::Courier)->create()->id,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * An online obligation waiting for its payment (Wave 5).
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function online(array $overrides = []): array
    {
        return $this->cash(array_merge([
            'method' => 'online',
            'status' => 'unpaid',
            'paid_at' => null,
            'recorded_by_user_id' => null,
            'attention_at' => now()->addMinutes(30),
        ], $overrides));
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'method' => ['character varying', false, 16],
            'provider' => ['character varying', true, 16],
            'amount_uzs' => ['bigint', false],
            'status' => ['character varying', false, 16],
            'attention_at' => ['timestamp with time zone', true],
            'paid_at' => ['timestamp with time zone', true],
            'cancelled_at' => ['timestamp with time zone', true],
            'recorded_by_user_id' => ['uuid', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);
    }

    public function test_an_order_has_one_live_payment_and_keeps_the_cancelled_ones(): void
    {
        DB::table(self::TABLE)->insert($this->online(['status' => 'cancelled', 'cancelled_at' => now()]));
        DB::table(self::TABLE)->insert($this->cash());

        $this->assertRejectedBy(
            self::TABLE,
            'payments_order_live_unique',
            $this->online(),
            '08 Section 21: one live payment per order.'
        );
        $this->assertStringContainsString("WHERE ((status)::text <> 'cancelled'::text)", $this->indexesOn(self::TABLE)['payments_order_live_unique']);
    }

    public function test_cash_is_only_ever_paid_and_recorded_by_a_person(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'payments_cash_check',
            $this->cash(['status' => 'unpaid', 'paid_at' => null]),
            'BR-PAY-003: cash exists only as the handover recorded it.'
        );
        $this->assertRejectedBy(self::TABLE, 'payments_cash_check', $this->cash(['recorded_by_user_id' => null]), 'The Courier recorded it.');
        $this->assertRejectedBy(self::TABLE, 'payments_cash_check', $this->cash(['provider' => 'payme']), 'Cash has no provider.');
        $this->assertRejectedBy(self::TABLE, 'payments_cash_check', $this->cash(['attention_at' => now()]), 'Cash owes no 30-minute window.');
        $this->assertRejectedBy(
            self::TABLE,
            'payments_online_check',
            $this->online(['recorded_by_user_id' => User::factory()->role(Role::Admin)->create()->id]),
            'BR-PAY-004: no role marks an online payment paid.'
        );
    }

    public function test_a_status_says_when_and_the_vocabularies_hold(): void
    {
        $this->assertRejectedBy(self::TABLE, 'payments_amount_check', $this->cash(['amount_uzs' => 0]), '08 Section 21: amount > 0.');
        $this->assertRejectedBy(self::TABLE, 'payments_cancelled_check', $this->online(['status' => 'cancelled']), 'A cancelled payment says when.');
        $this->assertRejectedBy(self::TABLE, 'payments_cancelled_check', $this->online(['cancelled_at' => now()]), 'Only a cancelled one does.');
        $this->assertRejectedBy(self::TABLE, 'payments_method_check', $this->cash(['method' => 'card']), 'BR-PAY-002.');
        $this->assertRejectedBy(self::TABLE, 'payments_paid_check', $this->online(['status' => 'paid']), 'A paid payment says when.');
        $this->assertRejectedBy(self::TABLE, 'payments_paid_check', $this->online(['paid_at' => now()]), 'Only a paid one does.');
        $this->assertRejectedBy(self::TABLE, 'payments_provider_check', $this->online(['provider' => 'visa']), 'DL-2 3.3.');
        $this->assertRejectedBy(self::TABLE, 'payments_status_check', $this->online(['status' => 'refunded']), 'BR-PAY-004.');

        DB::table(self::TABLE)->insert($this->online(['provider' => 'click']));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }
}
