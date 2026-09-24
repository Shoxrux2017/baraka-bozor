<?php

declare(strict_types=1);

namespace Tests\Unit\Auth;

use App\Modules\Auth\LoginCodePolicy;
use PHPUnit\Framework\TestCase;

/**
 * The patterns are anchored with `\z`, not `$`: `$` also matches before a
 * trailing newline. Over HTTP the framework trims input before validation,
 * so the patterns are the last line of defence for any other caller.
 */
final class LoginCodePolicyTest extends TestCase
{
    public function test_a_code_is_exactly_six_digits(): void
    {
        $this->assertTrue(LoginCodePolicy::isWellFormed('000000'));
        $this->assertFalse(LoginCodePolicy::isWellFormed('12345'));
        $this->assertFalse(LoginCodePolicy::isWellFormed('1234567'));
        $this->assertFalse(LoginCodePolicy::isWellFormed('12345a'));
        $this->assertFalse(LoginCodePolicy::isWellFormed("123456\n"));
    }

    public function test_a_phone_is_plus_998_and_nine_digits_with_nothing_after(): void
    {
        $this->assertSame(1, preg_match(LoginCodePolicy::PHONE_PATTERN, '+998901234567'));
        $this->assertSame(0, preg_match(LoginCodePolicy::PHONE_PATTERN, "+998901234567\n"));
        $this->assertSame(0, preg_match(LoginCodePolicy::PHONE_PATTERN, '998901234567'));
        $this->assertSame(0, preg_match(LoginCodePolicy::PHONE_PATTERN, '+99890123456'));
    }
}
