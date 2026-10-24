<?php

declare(strict_types=1);

namespace Tests\Unit\Auth;

use App\Modules\Auth\LoginCodePolicy;
use App\Modules\Auth\TestPhones;
use PHPUnit\Framework\Attributes\DataProvider;
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

    public function test_a_reviewer_phone_boots_in_production_and_gets_its_own_code(): void
    {
        $phones = new TestPhones([], null, production: true, reviewerPhone: '+998900000077', reviewerCode: '482913');

        $this->assertSame('482913', $phones->codeFor('+998900000077'));
        $this->assertTrue($phones->isReviewer('+998900000077'));
        $this->assertNull($phones->codeFor('+998901234567'));
        $this->assertFalse($phones->isReviewer('+998901234567'));
    }

    public function test_test_phones_still_refuse_to_boot_in_production_beside_a_reviewer(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('must be empty in production');

        new TestPhones(['+998900000099'], '000000', true, '+998900000077', '482913');
    }

    public function test_the_reviewer_code_is_not_a_test_phones_code(): void
    {
        $phones = new TestPhones(['+998900000099'], '000000', false, '+998900000077', '482913');

        $this->assertSame('000000', $phones->codeFor('+998900000099'));
        $this->assertSame('482913', $phones->codeFor('+998900000077'));
        $this->assertFalse($phones->isReviewer('+998900000099'));
    }

    /**
     * @return array<string, array{0: ?string, 1: ?string, 2: string}>
     */
    public static function badReviewerSettings(): array
    {
        return [
            'phone without code' => ['+998900000077', null, 'LOGIN_CODE_REVIEWER_CODE'],
            'code without phone' => [null, '482913', 'LOGIN_CODE_REVIEWER_PHONE'],
            'phone not +998' => ['+79001234567', '482913', 'LOGIN_CODE_REVIEWER_PHONE'],
            'phone too short' => ['+99890000007', '482913', 'LOGIN_CODE_REVIEWER_PHONE'],
            'code not digits' => ['+998900000077', '48a913', 'LOGIN_CODE_REVIEWER_CODE'],
            'code too short' => ['+998900000077', '48291', 'LOGIN_CODE_REVIEWER_CODE'],
            'repeated digits' => ['+998900000077', '000000', 'LOGIN_CODE_REVIEWER_CODE'],
            'ascending run' => ['+998900000077', '123456', 'LOGIN_CODE_REVIEWER_CODE'],
            'descending run' => ['+998900000077', '654321', 'LOGIN_CODE_REVIEWER_CODE'],
            'ascending run from zero' => ['+998900000077', '012345', 'LOGIN_CODE_REVIEWER_CODE'],
        ];
    }

    #[DataProvider('badReviewerSettings')]
    public function test_a_bad_reviewer_setting_refuses_to_boot_naming_the_setting_and_no_value(
        ?string $phone,
        ?string $code,
        string $setting,
    ): void {
        try {
            new TestPhones([], null, true, $phone, $code);
            $this->fail('The boot accepted a bad reviewer setting.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString($setting, $exception->getMessage());

            foreach (array_filter([$phone, $code]) as $value) {
                $this->assertStringNotContainsString($value, $exception->getMessage());
            }
        }
    }

    public function test_a_reviewer_code_equal_to_the_test_code_refuses_to_boot(): void
    {
        try {
            new TestPhones(['+998900000099'], '482913', false, '+998900000077', '482913');
            $this->fail('The boot accepted the test code as the reviewer code.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('LOGIN_CODE_REVIEWER_CODE', $exception->getMessage());
            $this->assertStringContainsString('LOGIN_CODE_TEST_CODE', $exception->getMessage());
            $this->assertStringNotContainsString('482913', $exception->getMessage());
        }
    }

    public function test_a_reviewer_phone_that_is_also_a_test_phone_refuses_to_boot(): void
    {
        try {
            new TestPhones(['+998900000077'], '000000', false, '+998900000077', '482913');
            $this->fail('The boot accepted the reviewer phone among the test phones.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('LOGIN_CODE_REVIEWER_PHONE', $exception->getMessage());
            $this->assertStringContainsString('LOGIN_CODE_TEST_PHONES', $exception->getMessage());
            $this->assertStringNotContainsString('+998900000077', $exception->getMessage());
        }
    }

    #[DataProvider('guessableCodes')]
    public function test_guessable_codes(string $code, bool $guessable): void
    {
        $this->assertSame($guessable, LoginCodePolicy::isGuessable($code));
    }

    /**
     * @return array<string, array{0: string, 1: bool}>
     */
    public static function guessableCodes(): array
    {
        return [
            'code 000000' => ['000000', true],
            'code 999999' => ['999999', true],
            'code 123456' => ['123456', true],
            'code 012345' => ['012345', true],
            'code 654321' => ['654321', true],
            'code 987654' => ['987654', true],
            'code 482913' => ['482913', false],
            'code 102938' => ['102938', false],
            'code 123465' => ['123465', false],
        ];
    }
}
