<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `customer_otp_challenges.channel`, docs/08 Section 4.
 */
final class LoginChallengeChannelColumnTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    public function test_the_column_is_a_non_null_string(): void
    {
        $column = $this->columnsOf('customer_otp_challenges')['channel'] ?? null;

        $this->assertNotNull($column);
        $this->assertSame('character varying', $column->data_type);
        $this->assertSame(16, $column->character_maximum_length);
        $this->assertSame('NO', $column->is_nullable);
    }

    public function test_only_the_four_channels_are_accepted(): void
    {
        $this->assertRejectedBy('customer_otp_challenges', 'customer_otp_challenges_channel_check', [
            'id' => (string) Str::uuid(),
            'phone' => '+998901234567',
            'purpose' => 'customer_login',
            'code_hash' => 'hash',
            'failed_attempts' => 0,
            'channel' => 'carrier_pigeon',
            'expires_at' => now()->addMinutes(5),
            'created_at' => now(),
        ], 'A code leaves by Telegram, SMS, the fake, or not at all for a test phone.');
    }
}
