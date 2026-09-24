<?php

declare(strict_types=1);

namespace Tests\Unit\Auth;

use App\Modules\Auth\TestPhones;
use PHPUnit\Framework\TestCase;
use RuntimeException;

final class TestPhonesTest extends TestCase
{
    public function test_a_listed_phone_gets_the_fixed_code_and_any_other_gets_nothing(): void
    {
        $phones = new TestPhones(['+998900000099'], '000000');

        $this->assertSame('000000', $phones->codeFor('+998900000099'));
        $this->assertNull($phones->codeFor('+998901234567'));
    }

    public function test_an_empty_list_needs_no_code_and_is_fine_in_production(): void
    {
        $phones = new TestPhones([], null, production: true);

        $this->assertNull($phones->codeFor('+998900000099'));
    }

    public function test_a_list_without_a_well_formed_code_fails_loudly(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('LOGIN_CODE_TEST_CODE');

        new TestPhones(['+998900000099'], '12ab');
    }

    public function test_any_test_phone_in_production_refuses_to_boot(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('must be empty in production');

        new TestPhones(['+998900000099'], '000000', production: true);
    }
}
