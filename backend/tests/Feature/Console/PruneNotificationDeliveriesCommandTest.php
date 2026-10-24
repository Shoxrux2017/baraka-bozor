<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\NotificationDelivery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `notification-deliveries:prune` — a delivery record kept ninety days is
 * deleted (`docs/08` section 26, `DL-112`).
 */
final class PruneNotificationDeliveriesCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_prunes_only_what_is_older_than_ninety_days_and_a_second_run_changes_nothing(): void
    {
        $this->travelTo(now()->startOfSecond());
        NotificationDelivery::factory()->create(['created_at' => now()->subDays(91)]);
        $kept = NotificationDelivery::factory()->create(['created_at' => now()->subDays(89)]);

        $this->artisan('notification-deliveries:prune')->expectsOutput('Pruned 1 notification delivery record(s).')->assertSuccessful();
        $this->assertSame([$kept->id], NotificationDelivery::query()->pluck('id')->all());

        $this->artisan('notification-deliveries:prune')->expectsOutput('Pruned 0 notification delivery record(s).')->assertSuccessful();
        $this->assertSame([$kept->id], NotificationDelivery::query()->pluck('id')->all());
    }
}
