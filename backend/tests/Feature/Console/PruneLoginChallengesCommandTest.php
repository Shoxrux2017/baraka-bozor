<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * `login-challenges:prune` — `DL-104` (8): a challenge older than thirty days
 * is deleted, whether or not it was ever used.
 */
final class PruneLoginChallengesCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_prunes_challenges_older_than_thirty_days_and_a_second_run_changes_nothing(): void
    {
        $this->travelTo(now()->startOfSecond());

        $this->challenge(now()->subDays(31));
        $kept = [$this->challenge(now()->subDays(29)), $this->challenge(now())];

        $this->artisan('login-challenges:prune')->expectsOutput('Pruned 1 login challenge(s).')->assertSuccessful();
        $this->assertEqualsCanonicalizing($kept, DB::table('customer_otp_challenges')->pluck('id')->all());

        $this->artisan('login-challenges:prune')->expectsOutput('Pruned 0 login challenge(s).')->assertSuccessful();
        $this->assertEqualsCanonicalizing($kept, DB::table('customer_otp_challenges')->pluck('id')->all());
    }

    private function challenge(CarbonInterface $createdAt): string
    {
        $id = (string) Str::uuid();
        DB::table('customer_otp_challenges')->insert([
            'id' => $id,
            'phone' => '+998901234567',
            'purpose' => 'customer_login',
            'code_hash' => 'x',
            'channel' => 'test',
            'expires_at' => $createdAt->copy()->addMinutes(5),
            'created_at' => $createdAt,
        ]);

        return $id;
    }
}
