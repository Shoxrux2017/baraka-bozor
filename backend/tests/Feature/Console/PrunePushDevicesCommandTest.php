<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\PushDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `push-devices:prune` — a device unseen for sixty days is revoked.
 */
final class PrunePushDevicesCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_revokes_devices_unseen_for_sixty_days_and_a_second_run_changes_nothing(): void
    {
        $this->travelTo(now()->startOfSecond());
        $stale = PushDevice::factory()->create(['last_seen_at' => now()->subDays(61), 'created_at' => now()->subDays(90)]);
        $neverSeen = PushDevice::factory()->create(['last_seen_at' => null, 'created_at' => now()->subDays(61)]);
        $seen = PushDevice::factory()->create(['last_seen_at' => now()->subDays(59), 'created_at' => now()->subDays(90)]);
        $recent = PushDevice::factory()->create(['last_seen_at' => null, 'created_at' => now()->subDays(10)]);
        $earlier = now()->subDays(100);
        $revoked = PushDevice::factory()->create(['last_seen_at' => now()->subDays(80), 'created_at' => now()->subDays(90), 'revoked_at' => $earlier]);

        $this->artisan('push-devices:prune')->expectsOutput('Revoked 2 push device(s) unseen for 60 days.')->assertSuccessful();

        $this->assertNotNull($stale->refresh()->revoked_at);
        $this->assertNotNull($neverSeen->refresh()->revoked_at);
        $this->assertNull($seen->refresh()->revoked_at);
        $this->assertNull($recent->refresh()->revoked_at);
        $this->assertTrue($revoked->refresh()->revoked_at->equalTo($earlier));

        $this->artisan('push-devices:prune')->expectsOutput('Revoked 0 push device(s) unseen for 60 days.')->assertSuccessful();
    }
}
