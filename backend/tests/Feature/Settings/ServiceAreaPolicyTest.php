<?php

declare(strict_types=1);

namespace Tests\Feature\Settings;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Modules\Settings\ServiceAreaPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * `BR-AREA-001` against the stored settings, and the customer price built
 * from the stored markup.
 */
final class ServiceAreaPolicyTest extends TestCase
{
    use RefreshDatabase;

    /** Tashkent, the centre the tests configure. */
    private const CENTRE_LAT = '41.311081';

    private const CENTRE_LNG = '69.240562';

    public function test_while_the_area_is_not_configured_the_answer_is_configuration_incomplete(): void
    {
        $this->assertRefusal(409, 'checkout_configuration_incomplete', [], self::CENTRE_LAT, self::CENTRE_LNG);

        $this->configure(radius: null);
        $this->assertRefusal(409, 'checkout_configuration_incomplete', [], self::CENTRE_LAT, self::CENTRE_LNG);
    }

    public function test_a_point_just_inside_the_radius_is_deliverable_and_one_just_beyond_is_not(): void
    {
        $this->configure(radius: '5.00');
        $policy = new ServiceAreaPolicy;

        // Due north along the meridian: 0.044876° ≈ 4.99 km, 0.045056° ≈ 5.01 km.
        $policy->assertDeliverable('41.355957', self::CENTRE_LNG);
        $policy->assertDeliverable(self::CENTRE_LAT, self::CENTRE_LNG);

        $this->assertRefusal(422, 'address_outside_service_area', [
            'max_distance_km' => '5.00',
            'distance_km' => '5.01',
        ], '41.356137', self::CENTRE_LNG);
    }

    public function test_the_customer_price_follows_the_stored_markup(): void
    {
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '15.00']);

        $this->assertSame(18_400, CustomerPriceCalculator::current()->priceOf(16_000));

        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '20.00']);

        $this->assertSame(19_200, CustomerPriceCalculator::current()->priceOf(16_000));
    }

    private function configure(?string $radius): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'service_centre_latitude' => self::CENTRE_LAT,
            'service_centre_longitude' => self::CENTRE_LNG,
            'service_radius_km' => $radius,
        ]);
    }

    /**
     * @param  array<string, string>  $details
     */
    private function assertRefusal(int $status, string $code, array $details, string $latitude, string $longitude): void
    {
        try {
            (new ServiceAreaPolicy)->assertDeliverable($latitude, $longitude);
            $this->fail("Expected {$status} {$code}.");
        } catch (ApiException $exception) {
            $this->assertSame($status, $exception->status());
            $this->assertSame($code, $exception->apiCode());
            $this->assertSame($details, $exception->details());
        }
    }
}
