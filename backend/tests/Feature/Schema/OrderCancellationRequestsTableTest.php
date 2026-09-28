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
 * `order_cancellation_requests`, as `docs/08-database.md` Section 20 names it,
 * with the status `closed` (`DL-54` (12)): one pending request per order
 * (`BR-CAN-002`), a reason, and the columns a decision or a closing implies.
 *
 * Each check is proven by a row only it refuses; PostgreSQL evaluates checks
 * in name order, so such a row satisfies every check named before it.
 */
final class OrderCancellationRequestsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_cancellation_requests';

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->order = Order::factory()->shopping()->create();
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => $this->order->id,
            'origin' => 'customer',
            'requested_by_user_id' => $this->order->customer_id,
            'status' => 'pending',
            'reason' => 'Планы изменились',
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * @return array<string, mixed>
     */
    private function decided(string $status): array
    {
        return ['status' => $status, 'resolved_by_user_id' => User::factory()->role(Role::Operator)->create()->id, 'resolved_at' => now()];
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'origin' => ['character varying', false, 16],
            'requested_by_user_id' => ['uuid', false],
            'status' => ['character varying', false, 16],
            'reason' => ['character varying', false, 300],
            'resolved_by_user_id' => ['uuid', true],
            'resolution_note' => ['character varying', true, 300],
            'resolved_at' => ['timestamp with time zone', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);

        $indexes = $this->indexesOn(self::TABLE);
        $this->assertStringContainsString('(status, created_at)', $indexes['order_cancellation_requests_status_created_at_index']);
        $this->assertStringContainsString('(order_id)', $indexes['order_cancellation_requests_order_id_index']);
    }

    public function test_an_order_has_one_pending_request_and_keeps_the_others(): void
    {
        DB::table(self::TABLE)->insert($this->row($this->decided('rejected')));
        DB::table(self::TABLE)->insert($this->row(['status' => 'closed', 'resolved_at' => now()]));
        DB::table(self::TABLE)->insert($this->row([...$this->decided('approved'), 'resolution_note' => 'Клиент подтвердил по телефону']));
        DB::table(self::TABLE)->insert($this->row());

        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_order_pending_unique',
            $this->row(),
            'BR-CAN-002: at most one pending request per order.'
        );
        $this->assertStringContainsString(
            "WHERE ((status)::text = 'pending'::text)",
            $this->indexesOn(self::TABLE)['order_cancellation_requests_order_pending_unique']
        );
    }

    public function test_each_status_carries_what_it_implies(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();

        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_closed_check',
            $this->row(['status' => 'closed']),
            'DL-54 (12): a closed request says when.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_closed_check',
            $this->row(['status' => 'closed', 'resolved_by_user_id' => $operator->id, 'resolved_at' => now()]),
            'Nobody decided a closed request.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_decided_check',
            $this->row(['status' => 'approved']),
            'BR-CAN-005: a decision names its actor and time.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_note_check',
            $this->row(['resolution_note' => 'Отказ']),
            'A resolution note is the decider\'s.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_note_check',
            $this->row([...$this->decided('rejected'), 'resolution_note' => ' ']),
            'A note says something.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_cancellation_requests_pending_check',
            $this->row(['resolved_at' => now()]),
            'Nobody resolved a pending request.'
        );
    }

    public function test_the_vocabularies_and_the_reason_are_enforced(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_cancellation_requests_origin_check', $this->row(['origin' => 'courier']), '08 Section 20.');
        $this->assertRejectedBy(self::TABLE, 'order_cancellation_requests_reason_check', $this->row(['reason' => ' ']), 'DL-37 (13): a request says why.');
        $this->assertRejectedBy(self::TABLE, 'order_cancellation_requests_status_check', $this->row(['status' => 'withdrawn']), 'DL-54 (12).');
    }
}
