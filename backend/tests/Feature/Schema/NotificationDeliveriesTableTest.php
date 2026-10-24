<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\NotificationType;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `notification_deliveries`, as `docs/08-database.md` Section 26 names it.
 */
final class NotificationDeliveriesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'notification_deliveries';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'user_id' => User::factory()->customer()->create()->id,
            'push_device_id' => null,
            'order_id' => null,
            'approval_id' => null,
            'type' => 'order_accepted',
            'status' => 'queued',
            'attempt_count' => 0,
            'sent_at' => null,
            'last_error_code' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_the_columns_are_those_of_docs_08_section_26(): void
    {
        $actual = $this->columnsOf(self::TABLE);

        $names = array_keys($actual);
        $expected = [
            'id', 'user_id', 'push_device_id', 'order_id', 'approval_id', 'type', 'status',
            'attempt_count', 'sent_at', 'last_error_code', 'created_at', 'updated_at',
        ];
        sort($names);
        sort($expected);
        $this->assertSame($expected, $names);

        $this->assertSame('YES', $actual['push_device_id']->is_nullable);
        $this->assertSame('YES', $actual['order_id']->is_nullable);
        $this->assertSame('YES', $actual['approval_id']->is_nullable);
        $this->assertSame('YES', $actual['sent_at']->is_nullable);
        $this->assertSame('YES', $actual['last_error_code']->is_nullable);
        $this->assertSame('NO', $actual['user_id']->is_nullable);
        $this->assertSame('NO', $actual['attempt_count']->is_nullable);
        $this->assertSame('timestamp with time zone', $actual['sent_at']->data_type);
    }

    public function test_type_accepts_the_thirteen_values_and_nothing_else(): void
    {
        $this->assertCount(13, NotificationType::cases());

        foreach (NotificationType::cases() as $type) {
            DB::table(self::TABLE)->insert($this->row(['type' => $type->value]));
        }

        $this->assertSame(13, DB::table(self::TABLE)->count());

        $this->assertRejectedBy(
            self::TABLE,
            'notification_deliveries_type_check',
            $this->row(['type' => 'order_shipped']),
            'Only the thirteen events of 05 Section 18 exist.'
        );
    }

    public function test_status_accepts_queued_sent_failed_skipped_only(): void
    {
        foreach (NotificationDeliveryStatus::cases() as $status) {
            DB::table(self::TABLE)->insert($this->row(['status' => $status->value]));
        }

        $this->assertSame(4, DB::table(self::TABLE)->count());

        $this->assertRejectedBy(
            self::TABLE,
            'notification_deliveries_status_check',
            $this->row(['status' => 'delivered']),
            'A delivery is queued, sent, failed or skipped.'
        );
    }

    public function test_deleting_a_device_keeps_the_row_with_no_device(): void
    {
        $device = PushDevice::factory()->create();
        $row = $this->row(['user_id' => $device->user_id, 'push_device_id' => $device->id]);
        DB::table(self::TABLE)->insert($row);

        DB::table('push_devices')->where('id', $device->id)->delete();

        $kept = DB::table(self::TABLE)->where('id', $row['id'])->first();
        $this->assertNotNull($kept);
        $this->assertNull($kept->push_device_id);
    }

    public function test_the_two_indexes_exist(): void
    {
        $indexes = $this->indexesOn(self::TABLE);

        $definitions = implode("\n", $indexes);
        $this->assertStringContainsString('(user_id, created_at)', $definitions);
        $this->assertStringContainsString('(status, created_at)', $definitions);
    }
}
