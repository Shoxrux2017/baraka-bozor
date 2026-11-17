<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\BusinessSettings;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The delivery zone the map draws (`docs/09` section 13, `DL-138` item 5).
 */
final class ServiceAreaApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/service-area';

    public function test_the_configured_area_is_answered(): void
    {
        $this->configure(['service_centre_latitude' => '41.311081', 'service_centre_longitude' => '69.240562', 'service_radius_km' => '10.00']);

        $this->asCustomer()->getJson(self::URL)
            ->assertOk()
            ->assertExactJson(['data' => ['latitude' => '41.311081', 'longitude' => '69.240562', 'radius_km' => '10.00']]);
    }

    /**
     * @return array<string, array{0: string}>
     */
    public static function unsetParts(): array
    {
        return [
            'latitude' => ['service_centre_latitude'],
            'longitude' => ['service_centre_longitude'],
            'radius' => ['service_radius_km'],
        ];
    }

    #[DataProvider('unsetParts')]
    public function test_an_unset_area_answers_null(string $unset): void
    {
        $this->configure(['service_centre_latitude' => '41.311081', 'service_centre_longitude' => '69.240562', 'service_radius_km' => '10.00']);
        $this->configure([$unset => null]);

        $this->asCustomer()->getJson(self::URL)->assertOk()->assertExactJson(['data' => null]);
    }

    public function test_only_a_customer_may_read_it(): void
    {
        $this->getJson(self::URL)->assertStatus(401);

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)->getJson(self::URL)->assertStatus(403);
    }

    /**
     * @param  array<string, string|null>  $values
     */
    private function configure(array $values): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update($values);
    }

    private function asCustomer(): self
    {
        $customer = User::factory()->customer()->create();

        return $this->withToken($customer->createToken('t')->plainTextToken);
    }
}
