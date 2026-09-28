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
 * `order_courier_assignments`, as `docs/08-database.md` Section 17 names it:
 * one current assignment per order (`BR-CON-002`), the delivery's steps in
 * order with its delay instant (`BR-DEL-002`), and a failure's reason
 * (`BR-DEL-003`).
 *
 * Each check is proven by a row only it refuses; PostgreSQL evaluates checks
 * in name order, so such a row satisfies every check named before it.
 */
final class OrderCourierAssignmentsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_courier_assignments';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => Order::factory()->readyForDelivery()->create()->id,
            'courier_id' => User::factory()->role(Role::Courier)->create()->id,
            'assigned_by_user_id' => User::factory()->role(Role::Operator)->create()->id,
            'is_self_order' => false,
            'assigned_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * A delivery that set off and came back undelivered.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function failed(array $overrides = []): array
    {
        return $this->row(array_merge([
            'accepted_at' => now(),
            'delivery_started_at' => now(),
            'delay_at' => now()->addHour(),
            'ended_at' => now(),
            'ended_reason' => 'delivery_failed',
            'failed_reason_code' => 'no_answer',
        ], $overrides));
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'courier_id' => ['uuid', false],
            'assigned_by_user_id' => ['uuid', false],
            'is_self_order' => ['boolean', false],
            'assigned_at' => ['timestamp with time zone', false],
            'accepted_at' => ['timestamp with time zone', true],
            'delivery_started_at' => ['timestamp with time zone', true],
            'delay_at' => ['timestamp with time zone', true],
            'completed_at' => ['timestamp with time zone', true],
            'ended_at' => ['timestamp with time zone', true],
            'ended_reason' => ['character varying', true, 24],
            'failed_reason_code' => ['character varying', true, 24],
            'failed_note' => ['character varying', true, 300],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);

        $indexes = $this->indexesOn(self::TABLE);
        $this->assertStringContainsString('WHERE (ended_at IS NULL)', $indexes['order_courier_assignments_courier_current_index']);
        $this->assertStringContainsString('(delay_at)', $indexes['order_courier_assignments_delay_at_index']);
        $this->assertStringContainsString('(order_id)', $indexes['order_courier_assignments_order_id_index']);
    }

    public function test_an_order_has_one_current_assignment_and_keeps_the_ended_ones(): void
    {
        $order = Order::factory()->readyForDelivery()->create();
        DB::table(self::TABLE)->insert($this->failed(['order_id' => $order->id]));
        DB::table(self::TABLE)->insert($this->row(['order_id' => $order->id]));

        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_order_current_unique',
            $this->row(['order_id' => $order->id]),
            'BR-CON-002: one current Courier assignment per order.'
        );
        $this->assertStringContainsString('WHERE (ended_at IS NULL)', $this->indexesOn(self::TABLE)['order_courier_assignments_order_current_unique']);
    }

    public function test_the_delivery_steps_come_in_order_with_their_delay_instant(): void
    {
        $now = now();

        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_completed_check',
            $this->row(['accepted_at' => now(), 'completed_at' => now()]),
            'A delivery completes after it set off.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_completed_end_check',
            $this->row([
                'accepted_at' => now(),
                'delivery_started_at' => now(),
                'delay_at' => now()->addHour(),
                'ended_at' => now(),
                'ended_reason' => 'completed',
            ]),
            'An assignment ended as completed records its completion.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_completed_end_check',
            $this->row([
                'accepted_at' => $now,
                'delivery_started_at' => $now,
                'delay_at' => $now->copy()->addHour(),
                'completed_at' => $now,
            ]),
            'A completion is the end as completed.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_delay_check',
            $this->row(['accepted_at' => now(), 'delivery_started_at' => now()]),
            'BR-DEL-002: a start fixes when the order becomes late.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_delay_check',
            $this->row(['accepted_at' => $now, 'delivery_started_at' => $now, 'delay_at' => $now]),
            'The delay instant is after the start.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_started_check',
            $this->row(['delivery_started_at' => now(), 'delay_at' => now()->addHour()]),
            'BR-ASSIGN-003: accept before start.'
        );
    }

    public function test_an_end_says_why_and_a_failure_says_what_went_wrong(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_courier_assignments_ended_check', $this->row(['ended_at' => now()]), 'An end says why.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_ended_reason_check',
            $this->row(['ended_at' => now(), 'ended_reason' => 'lost']),
            'DL-3 S-9.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_check',
            $this->failed(['failed_reason_code' => null]),
            'BR-DEL-003: a failed delivery says why.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_check',
            $this->row(['failed_reason_code' => 'refused']),
            'Only a failed delivery carries a failure reason.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_check',
            $this->failed(['delivery_started_at' => null, 'delay_at' => null]),
            'A delivery fails only after it set off.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_note_check',
            $this->row(['failed_note' => 'Звонил дважды']),
            'A note explains a failure.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_note_check',
            $this->failed(['failed_note' => ' ']),
            'A note says something.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_failed_reason_check',
            $this->failed(['failed_reason_code' => 'lost']),
            'BR-DEL-003: the four reasons.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_courier_assignments_other_note_check',
            $this->failed(['failed_reason_code' => 'other']),
            'docs/09 section 37: `other` comes with a note.'
        );

        foreach (['reassigned', 'order_cancelled'] as $reason) {
            $this->assertRejectedBy(
                self::TABLE,
                'order_courier_assignments_unstarted_end_check',
                $this->failed(['ended_reason' => $reason, 'failed_reason_code' => null]),
                "BR-ASSIGN-002, BR-CAN-003: an assignment ends {$reason} only before it set off."
            );
        }

        DB::table(self::TABLE)->insert($this->failed(['failed_reason_code' => 'other', 'failed_note' => 'Шлагбаум закрыт']));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }
}
