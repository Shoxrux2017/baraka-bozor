<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use Illuminate\Console\Scheduling\Schedule;
use Tests\TestCase;

/**
 * The scheduler runs exactly the entries Wave 4 defines (`DL-104` (8)).
 */
final class ScheduleTest extends TestCase
{
    public function test_the_schedule_is_exactly_the_wave_4_entries(): void
    {
        $actual = [];
        foreach (app(Schedule::class)->events() as $event) {
            $actual[] = [
                preg_replace("/^.*?artisan'?\s+/", '', (string) $event->command),
                $event->expression,
                $event->timezone === null ? null : (string) $event->timezone,
            ];
        }

        $this->assertSame([
            ['approvals:expire', '* * * * *', config('app.timezone')],
            ['idempotency-keys:prune', '0 4 * * *', 'Asia/Tashkent'],
            ['notification-deliveries:prune', '0 4 * * *', 'Asia/Tashkent'],
            ['push-devices:prune', '0 4 * * *', 'Asia/Tashkent'],
            ['login-challenges:prune', '0 4 * * *', 'Asia/Tashkent'],
            ['queue:prune-failed --hours=720', '0 4 * * *', 'Asia/Tashkent'],
        ], $actual);
    }
}
