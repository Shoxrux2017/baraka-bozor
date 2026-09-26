<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\BusinessSettings;
use App\Models\CustomerAddress;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The Customer's own addresses (`docs/09` section 13, `BR-AREA-001`,
 * `DL-17` (6) and (7), `DL-23`).
 */
final class AddressesApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/addresses';

    /** Tashkent, the centre the tests configure, with a 5.00 km radius. */
    private const CENTRE_LAT = '41.311081';

    private const CENTRE_LNG = '69.240562';

    /** Due north along the meridian: about 4.990 km, inside. */
    private const INSIDE_LAT = '41.355957';

    /** Due north along the meridian: about 5.008 km, outside. */
    private const OUTSIDE_LAT = '41.356120';

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
        $this->configureArea();
    }

    public function test_an_address_inside_the_area_is_created_for_the_caller(): void
    {
        $response = $this->asCustomer()->postJson(self::URL, [
            'label' => 'Uy',
            'latitude' => self::INSIDE_LAT,
            'longitude' => self::CENTRE_LNG,
            'street' => 'Amir Temur shoh ko\'chasi',
            'house' => '12A',
            'apartment' => '45',
            'landmark' => 'Metro yonida',
            'delivery_note' => 'Domofon ishlamaydi',
        ])->assertCreated();

        $data = $response->json('data');
        $this->assertSame(
            ['id', 'label', 'latitude', 'longitude', 'street', 'house', 'apartment', 'landmark', 'delivery_note', 'created_at', 'updated_at'],
            array_keys($data)
        );
        $this->assertSame(self::INSIDE_LAT, $data['latitude']);
        $this->assertSame(self::CENTRE_LNG, $data['longitude']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $data['created_at']);

        $address = CustomerAddress::query()->findOrFail($data['id']);
        $this->assertSame($this->customer->id, $address->customer_id);
        $this->assertTrue($address->is_active);
    }

    public function test_the_optional_fields_may_be_left_out_and_short_coordinates_are_widened(): void
    {
        $this->asCustomer()->postJson(self::URL, [
            'latitude' => '41.3',
            'longitude' => '69.24',
            'street' => 'Navoiy',
            'house' => '1',
        ])
            ->assertCreated()
            ->assertJsonPath('data.latitude', '41.300000')
            ->assertJsonPath('data.longitude', '69.240000')
            ->assertJsonPath('data.label', null)
            ->assertJsonPath('data.delivery_note', null);
    }

    public function test_a_point_outside_the_area_is_refused_with_both_distances(): void
    {
        $this->asCustomer()->postJson(self::URL, $this->body(['latitude' => self::OUTSIDE_LAT]))
            ->assertStatus(422)
            ->assertJsonPath('code', 'address_outside_service_area')
            ->assertJsonPath('details.max_distance_km', '5.00')
            ->assertJsonPath('details.distance_km', '5.01');

        $this->assertSame(0, CustomerAddress::query()->count());
    }

    public function test_while_the_area_is_unset_an_address_cannot_be_created(): void
    {
        $this->configureArea(radius: null);

        $this->asCustomer()->postJson(self::URL, $this->body())
            ->assertStatus(409)
            ->assertJsonPath('code', 'checkout_configuration_incomplete');

        $this->assertSame(0, CustomerAddress::query()->count());
    }

    public function test_the_point_street_and_house_are_required_and_checked(): void
    {
        foreach ([
            'latitude' => [null, '', 41.3, '91', '-90.000001', '41.3111111', '41,3', '1e1', '+41.3'],
            'longitude' => [null, 69.24, '180.000001', '69.2405621', '0x45'],
            'street' => [null, '', '   ', str_repeat('a', 161)],
            'house' => [null, '', str_repeat('1', 41)],
            'label' => [str_repeat('a', 61)],
            'apartment' => [str_repeat('a', 41)],
            'landmark' => [str_repeat('a', 161)],
            'delivery_note' => [str_repeat('a', 301)],
        ] as $field => $values) {
            foreach ($values as $value) {
                $this->asCustomer()->postJson(self::URL, $this->body([$field => $value]))
                    ->assertStatus(422)
                    ->assertJsonPath('code', 'validation_failed')
                    ->assertJsonValidationErrorFor($field, 'errors');
            }
        }

        $body = $this->body();
        unset($body['longitude']);
        $this->asCustomer()->postJson(self::URL, $body)->assertStatus(422)->assertJsonValidationErrorFor('longitude', 'errors');

        $this->assertSame(0, CustomerAddress::query()->count());
    }

    public function test_the_bounds_themselves_are_accepted(): void
    {
        $this->asCustomer()->postJson(self::URL, $this->body([
            'street' => str_repeat('a', 160),
            'house' => str_repeat('1', 40),
            'label' => str_repeat('a', 60),
            'apartment' => str_repeat('a', 40),
            'landmark' => str_repeat('a', 160),
            'delivery_note' => str_repeat('a', 300),
        ]))->assertCreated();
    }

    public function test_the_owner_and_the_active_flag_are_not_request_fields(): void
    {
        $other = User::factory()->customer()->create();

        foreach ([['customer_id' => $other->id], ['is_active' => false], ['id' => (string) Str::uuid()]] as $extra) {
            $this->asCustomer()->postJson(self::URL, $this->body($extra))
                ->assertStatus(422)
                ->assertJsonValidationErrorFor((string) array_key_first($extra), 'errors');
        }

        $this->assertSame(0, CustomerAddress::query()->count());
    }

    public function test_the_list_holds_only_the_callers_active_addresses_newest_first(): void
    {
        $older = $this->address(['label' => 'Ish', 'created_at' => Carbon::parse('2026-09-20 10:00:00')]);
        $newer = $this->address(['label' => 'Uy', 'created_at' => Carbon::parse('2026-09-25 10:00:00')]);
        $this->address(['label' => 'Eski'], active: false);
        CustomerAddress::factory()->create(['label' => 'Begona']);

        $this->asCustomer()->getJson(self::URL)
            ->assertOk()
            ->assertJsonPath('data.*.id', [$newer->id, $older->id])
            ->assertJsonPath('meta.pagination.total', 2);

        $this->asCustomer()->getJson(self::URL.'?per_page=1&page=2')
            ->assertOk()
            ->assertJsonPath('data.*.id', [$older->id]);
    }

    public function test_the_caller_sees_their_address_and_nothing_else(): void
    {
        $own = $this->address();
        $foreign = CustomerAddress::factory()->create();
        $inactive = $this->address(active: false);

        $this->asCustomer()->getJson(self::URL.'/'.$own->id)->assertOk()->assertJsonPath('data.id', $own->id);

        foreach ([$foreign->id, $inactive->id, (string) Str::uuid(), 'not-a-uuid'] as $id) {
            $this->asCustomer()->getJson(self::URL.'/'.$id)
                ->assertStatus(404)
                ->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_an_update_changes_only_the_fields_sent(): void
    {
        $address = $this->address(['house' => '12', 'apartment' => '4', 'label' => 'Uy']);

        $this->asCustomer()->patchJson(self::URL.'/'.$address->id, ['house' => '14', 'label' => null])
            ->assertOk()
            ->assertJsonPath('data.house', '14')
            ->assertJsonPath('data.label', null)
            ->assertJsonPath('data.apartment', '4')
            ->assertJsonPath('data.latitude', $address->latitude);
    }

    public function test_an_update_that_moves_the_point_checks_the_area(): void
    {
        $address = $this->address();
        $url = self::URL.'/'.$address->id;

        $this->asCustomer()->patchJson($url, ['latitude' => self::INSIDE_LAT, 'longitude' => self::CENTRE_LNG])
            ->assertOk()
            ->assertJsonPath('data.latitude', self::INSIDE_LAT);

        $this->asCustomer()->patchJson($url, ['latitude' => self::OUTSIDE_LAT, 'longitude' => self::CENTRE_LNG, 'house' => '99'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'address_outside_service_area');

        $fresh = $address->fresh();

        $this->assertNotNull($fresh);
        $this->assertSame(self::INSIDE_LAT, $fresh->latitude);
        $this->assertNotSame('99', $fresh->house);
    }

    public function test_the_two_coordinates_travel_together(): void
    {
        $address = $this->address();
        $url = self::URL.'/'.$address->id;

        $this->asCustomer()->patchJson($url, ['latitude' => self::INSIDE_LAT])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('longitude', 'errors');
        $this->asCustomer()->patchJson($url, ['longitude' => self::CENTRE_LNG])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('latitude', 'errors');
        $this->asCustomer()->patchJson($url, ['latitude' => null, 'longitude' => null])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('latitude', 'errors')
            ->assertJsonValidationErrorFor('longitude', 'errors');
        $this->asCustomer()->patchJson($url, ['street' => '', 'house' => null])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('street', 'errors')
            ->assertJsonValidationErrorFor('house', 'errors');

        $this->assertSame(self::CENTRE_LAT, $address->fresh()?->latitude);
    }

    public function test_an_update_that_keeps_the_point_works_even_after_the_area_changed(): void
    {
        $address = $this->address(['latitude' => self::OUTSIDE_LAT, 'house' => '1']);
        $this->configureArea(radius: null);

        $this->asCustomer()->patchJson(self::URL.'/'.$address->id, ['house' => '1B'])
            ->assertOk()
            ->assertJsonPath('data.house', '1B');

        $this->asCustomer()->patchJson(self::URL.'/'.$address->id, ['latitude' => self::CENTRE_LAT, 'longitude' => self::CENTRE_LNG])
            ->assertStatus(409)
            ->assertJsonPath('code', 'checkout_configuration_incomplete');
    }

    public function test_another_customers_address_is_not_found_whatever_the_body(): void
    {
        $foreign = CustomerAddress::factory()->create(['house' => '7']);
        $url = self::URL.'/'.$foreign->id;

        foreach ([
            ['house' => '8'],
            ['latitude' => self::OUTSIDE_LAT, 'longitude' => self::CENTRE_LNG],
        ] as $body) {
            $this->asCustomer()->patchJson($url, $body)
                ->assertStatus(404)
                ->assertJsonPath('code', 'resource_not_found');
        }
        $this->asCustomer()->deleteJson($url)->assertStatus(404)->assertJsonPath('code', 'resource_not_found');

        $fresh = $foreign->fresh();

        $this->assertNotNull($fresh);
        $this->assertSame('7', $fresh->house);
        $this->assertTrue($fresh->is_active);
    }

    public function test_an_empty_update_is_refused(): void
    {
        $address = $this->address();

        $this->asCustomer()->patchJson(self::URL.'/'.$address->id, [])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('body', 'errors');
    }

    public function test_delete_deactivates_and_the_address_is_then_gone_for_the_customer(): void
    {
        $address = $this->address();
        $url = self::URL.'/'.$address->id;

        $this->asCustomer()->deleteJson($url)->assertNoContent();

        $this->assertDatabaseHas('customer_addresses', ['id' => $address->id, 'is_active' => false]);
        $this->asCustomer()->getJson($url)->assertStatus(404);
        $this->asCustomer()->patchJson($url, ['house' => '2'])->assertStatus(404);
        $this->asCustomer()->deleteJson($url)->assertStatus(404);
        $this->asCustomer()->getJson(self::URL)->assertOk()->assertJsonPath('meta.pagination.total', 0);
    }

    public function test_delete_works_while_the_area_is_unset(): void
    {
        $address = $this->address();
        $this->configureArea(radius: null);

        $this->asCustomer()->deleteJson(self::URL.'/'.$address->id)->assertNoContent();
    }

    public function test_staff_have_no_customer_addresses(): void
    {
        $address = $this->address();

        foreach ([Role::Admin, Role::Operator, Role::Manager, Role::Shopper, Role::Courier] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;
            $url = self::URL.'/'.$address->id;

            foreach ([
                $this->withToken($token)->getJson(self::URL),
                $this->withToken($token)->postJson(self::URL, $this->body()),
                $this->withToken($token)->getJson($url),
                $this->withToken($token)->patchJson($url, ['house' => '9']),
                $this->withToken($token)->deleteJson($url),
            ] as $response) {
                $response->assertStatus(403)->assertJsonPath('code', 'forbidden');
            }
        }

        $this->assertTrue($address->fresh()?->is_active);
        $this->assertSame(1, CustomerAddress::query()->count());
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $this->getJson(self::URL)->assertStatus(401)->assertJsonPath('code', 'authentication_required');
        $this->postJson(self::URL, $this->body())->assertStatus(401);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function body(array $overrides = []): array
    {
        return array_merge([
            'latitude' => self::CENTRE_LAT,
            'longitude' => self::CENTRE_LNG,
            'street' => 'Amir Temur shoh ko\'chasi',
            'house' => '12',
        ], $overrides);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function address(array $attributes = [], bool $active = true): CustomerAddress
    {
        return CustomerAddress::factory()
            ->state(['customer_id' => $this->customer->id, 'is_active' => $active])
            ->create($attributes);
    }

    private function configureArea(?string $radius = '5.00'): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'service_centre_latitude' => self::CENTRE_LAT,
            'service_centre_longitude' => self::CENTRE_LNG,
            'service_radius_km' => $radius,
        ]);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
