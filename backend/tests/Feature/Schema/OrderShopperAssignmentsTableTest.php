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
 * `order_shopper_assignments`, as `docs/08-database.md` Section 16 names it:
 * one current assignment per order (`BR-CON-002`), ended rather than deleted.
 */
final class OrderShopperAssignmentsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_shopper_assignments';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => Order::factory()->create()->id,
            'shopper_id' => User::factory()->role(Role::Shopper)->create()->id,
            'assigned_by_user_id' => User::factory()->role(Role::Operator)->create()->id,
            'is_self_order' => false,
            'assigned_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'shopper_id' => ['uuid', false],
            'assigned_by_user_id' => ['uuid', false],
            'is_self_order' => ['boolean', false],
            'assigned_at' => ['timestamp with time zone', false],
            'accepted_at' => ['timestamp with time zone', true],
            'started_at' => ['timestamp with time zone', true],
            'completed_at' => ['timestamp with time zone', true],
            'ended_at' => ['timestamp with time zone', true],
            'ended_reason' => ['character varying', true, 24],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);
    }

    public function test_an_order_has_one_current_assignment_and_keeps_the_ended_ones(): void
    {
        $order = Order::factory()->create();
        DB::table(self::TABLE)->insert($this->row(['order_id' => $order->id, 'ended_at' => now(), 'ended_reason' => 'reassigned']));
        DB::table(self::TABLE)->insert($this->row(['order_id' => $order->id]));

        $this->assertRejectedBy(
            self::TABLE,
            'order_shopper_assignments_order_current_unique',
            $this->row(['order_id' => $order->id]),
            'BR-CON-002: two Operators assigning at once cannot both win.'
        );
        $this->assertStringContainsString('WHERE (ended_at IS NULL)', $this->indexesOn(self::TABLE)['order_shopper_assignments_order_current_unique']);
        $this->assertStringContainsString('WHERE (ended_at IS NULL)', $this->indexesOn(self::TABLE)['order_shopper_assignments_shopper_current_index']);
    }

    public function test_an_end_has_its_reason_and_the_steps_come_in_order(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_shopper_assignments_ended_check', $this->row(['ended_at' => now()]), 'An end says why.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_shopper_assignments_ended_reason_check',
            $this->row(['ended_at' => now(), 'ended_reason' => 'delivery_failed']),
            'A Shopper\'s assignment does not end in a delivery failure.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_shopper_assignments_started_check', $this->row(['started_at' => now()]), 'BR-ASSIGN-003: accept before start.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_shopper_assignments_completed_check',
            $this->row(['accepted_at' => now(), 'completed_at' => now()]),
            'Completion follows a start.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_shopper_assignments_completed_end_check',
            $this->row(['accepted_at' => now(), 'started_at' => now(), 'ended_at' => now(), 'ended_reason' => 'completed']),
            'An assignment ended as completed records its completion.'
        );
    }
}
