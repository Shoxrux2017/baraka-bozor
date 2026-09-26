<?php

declare(strict_types=1);

namespace Tests\Unit\Settings;

use App\Modules\Settings\CustomerPriceCalculator;
use App\Modules\Settings\ServiceAreaPolicy;
use App\Support\Money\Percentage;
use PHPUnit\Framework\TestCase;

/**
 * The pure halves of the settings module: the great-circle distance and the
 * customer price for a given markup.
 */
final class ServiceAreaDistanceTest extends TestCase
{
    public function test_the_same_point_is_zero_kilometres_away(): void
    {
        $this->assertSame(0.0, ServiceAreaPolicy::distanceKm('41.311081', '69.240562', '41.311081', '69.240562'));
    }

    public function test_a_point_due_north_is_the_arc_length_along_the_meridian(): void
    {
        // Along a meridian the distance is R × Δφ exactly: 0.044966° ≈ 5.0000 km.
        $distance = ServiceAreaPolicy::distanceKm('41.311081', '69.240562', '41.356047', '69.240562');

        $this->assertEqualsWithDelta(5.0, $distance, 0.001);
    }

    public function test_tashkent_to_samarkand_is_about_two_hundred_and_sixty_six_kilometres(): void
    {
        $distance = ServiceAreaPolicy::distanceKm('41.311081', '69.240562', '39.654167', '66.959722');

        $this->assertEqualsWithDelta(266.0, $distance, 5.0);
    }

    public function test_the_customer_price_is_the_market_price_plus_the_markup_rounded_half_up(): void
    {
        $calculator = new CustomerPriceCalculator(Percentage::fromString('15'));

        $this->assertSame(18_400, $calculator->priceOf(16_000));
        $this->assertSame(12, $calculator->priceOf(10)); // 11.5 → 12
    }
}
