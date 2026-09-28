<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `order_history`, as `docs/08-database.md` Section 15 names it: the event
 * vocabulary, the actor rule, `details` as an object, and append-only.
 */
final class OrderHistoryTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_history';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => Order::factory()->create()->id,
            'event_type' => 'status_changed',
            'from_status' => null,
            'to_status' => 'new',
            'actor_type' => 'user',
            'actor_user_id' => User::factory()->customer()->create()->id,
            'reason_code' => null,
            'note' => null,
            'details' => null,
            'created_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'event_type' => ['character varying', false, 40],
            'from_status' => ['character varying', true, 32],
            'to_status' => ['character varying', true, 32],
            'actor_type' => ['character varying', false, 24],
            'actor_user_id' => ['uuid', true],
            'reason_code' => ['character varying', true, 40],
            'note' => ['text', true],
            'details' => ['jsonb', true],
            'created_at' => ['timestamp with time zone', false],
        ]);
        $this->assertStringContainsString('(order_id, created_at)', $this->indexesOn(self::TABLE)['order_history_order_id_created_at_index']);
    }

    public function test_an_edit_with_its_details_is_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row([
            'event_type' => 'edited',
            'to_status' => null,
            'details' => json_encode(['added' => [], 'removed' => ['line'], 'changed' => []]),
        ]));

        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_the_events_of_wave_3_actions_are_accepted(): void
    {
        foreach ([
            'shopper_accepted', 'courier_accepted', 'item_purchased', 'item_unavailable', 'item_substituted',
            'cancellation_requested', 'cancellation_request_decided', 'payment_recorded',
        ] as $event) {
            DB::table(self::TABLE)->insert($this->row(['event_type' => $event, 'to_status' => null]));
        }

        $this->assertSame(8, DB::table(self::TABLE)->count(), 'DL-54 (2): the history explains every action.');
    }

    public function test_the_vocabularies_are_enforced(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_history_event_type_check', $this->row(['event_type' => 'status_updated']), '08 Section 15.');
        $this->assertRejectedBy(self::TABLE, 'order_history_statuses_check', $this->row(['to_status' => 'approval_required']), 'DL-3 S-6.');
        $this->assertRejectedBy(self::TABLE, 'order_history_reason_code_check', $this->row(['reason_code' => 'bored']), 'DL-3 S-9.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_history_actor_type_check',
            $this->row(['actor_type' => 'robot', 'actor_user_id' => null]),
            'A user, the system or a payment provider.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_history_details_object_check',
            $this->row(['details' => json_encode(['a list'])]),
            'details holds named facts.'
        );
    }

    public function test_only_a_user_row_names_its_actor(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_history_actor_user_check', $this->row(['actor_user_id' => null]), 'A user event says which user.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_history_actor_user_check',
            $this->row(['actor_type' => 'system', 'actor_user_id' => User::factory()->role(Role::Admin)->create()->id]),
            'A system event is nobody\'s.'
        );
    }

    public function test_a_row_cannot_be_changed_or_deleted(): void
    {
        $row = $this->row();
        DB::table(self::TABLE)->insert($row);

        foreach ([
            fn () => DB::table(self::TABLE)->where('id', $row['id'])->update(['note' => 'rewritten']),
            fn () => DB::table(self::TABLE)->where('id', $row['id'])->delete(),
        ] as $change) {
            DB::beginTransaction();

            try {
                $change();
                $this->fail('docs/05 section 22: no path bypasses the history.');
            } catch (QueryException $refusal) {
                $this->assertStringContainsString('order_history is append-only', $refusal->getMessage());
            } finally {
                DB::rollBack();
            }
        }

        $this->assertNull(DB::table(self::TABLE)->where('id', $row['id'])->value('note'));
    }
}
