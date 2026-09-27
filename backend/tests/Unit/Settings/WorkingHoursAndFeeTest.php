<?php

declare(strict_types=1);

namespace Tests\Unit\Settings;

use App\Models\Enums\ServiceFeeMode;
use App\Modules\Settings\ServiceFeeCalculator;
use App\Modules\Settings\WorkingHours;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use Carbon\CarbonImmutable;
use Tests\TestCase;

/**
 * The working hours of `BR-SET-001` in `Asia/Tashkent` (UTC+5), and the
 * service fee of `BR-MONEY-005`.
 */
final class WorkingHoursAndFeeTest extends TestCase
{
    public function test_hours_within_one_day_open_at_opening_and_close_at_closing(): void
    {
        $hours = WorkingHours::of('08:00', '22:00:00');

        $this->assertFalse($hours->isOpenAt($this->tashkent('07:59')));
        $this->assertTrue($hours->isOpenAt($this->tashkent('08:00')));
        $this->assertTrue($hours->isOpenAt($this->tashkent('21:59')));
        $this->assertFalse($hours->isOpenAt($this->tashkent('22:00')));
        $this->assertSame('08:00', $hours->opensAt());
        $this->assertFalse($hours->isAlwaysOpen());
    }

    public function test_hours_that_close_before_they_open_span_midnight(): void
    {
        $hours = WorkingHours::of('22:00', '02:00');

        $this->assertTrue($hours->isOpenAt($this->tashkent('23:30')));
        $this->assertTrue($hours->isOpenAt($this->tashkent('01:59')));
        $this->assertFalse($hours->isOpenAt($this->tashkent('02:00')));
        $this->assertFalse($hours->isOpenAt($this->tashkent('12:00')));
    }

    public function test_the_round_the_clock_pair_is_always_open(): void
    {
        $hours = WorkingHours::of('00:00', '23:59');

        $this->assertTrue($hours->isAlwaysOpen());
        $this->assertTrue($hours->isOpenAt($this->tashkent('23:59')));
    }

    public function test_the_hours_are_tashkents_whatever_the_instants_zone(): void
    {
        // 03:30 UTC is 08:30 in Tashkent.
        $this->assertTrue(WorkingHours::of('08:00', '22:00')->isOpenAt(CarbonImmutable::parse('2026-09-27 03:30:00', 'UTC')));
        $this->assertFalse(WorkingHours::of('08:00', '22:00')->isOpenAt(CarbonImmutable::parse('2026-09-27 02:30:00', 'UTC')));
    }

    public function test_a_fixed_fee_is_its_amount_and_a_percentage_rounds_half_up(): void
    {
        $this->assertSame(5000, (new ServiceFeeCalculator(ServiceFeeMode::Fixed, 5000, null))->feeOn(123456));
        // 3 % of 100 050 = 3 001.5 → 3 002; of 100 016 = 3 000.48 → 3 000.
        $percent = new ServiceFeeCalculator(ServiceFeeMode::Percentage, null, '3.00');
        $this->assertSame(3002, $percent->feeOn(100050));
        $this->assertSame(3000, $percent->feeOn(100016));
        $this->assertSame(0, $percent->feeOn(0));
        $this->assertSame(1, MoneyCalculator::percentOf(1, Percentage::fromString('50.00')));
    }

    private function tashkent(string $time): CarbonImmutable
    {
        return CarbonImmutable::parse("2026-09-27 {$time}:00", WorkingHours::ZONE);
    }
}
