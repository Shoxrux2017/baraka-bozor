<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;
use App\Models\CartItem;
use App\Models\CustomerAddress;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\Role;
use App\Models\Enums\UnitCode;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\Checkout\CheckoutSecrets;
use App\Modules\Orders\Checkout\CheckoutState;
use App\Modules\Orders\Checkout\CheckoutToken;
use App\Modules\Orders\CustomerCart;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use Tests\TestCase;

/**
 * The checkout preview, `docs/09` section 18: the amounts, the working-hours
 * note, every refusal in the order of `DL-37` (21), and the token of `DL-37`
 * (4). Settings: a 15 % markup, a fixed fee of 5 000, delivery 15 000, a
 * minimum of 50 000, open 08:00–22:00, a 5 km circle around the centre.
 */
final class CheckoutPreviewApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/checkout/preview';

    private User $customer;

    private CustomerAddress $address;

    /** Estimate, per kg: market 16 000, customer 18 400. */
    private Product $tomatoes;

    /** Fixed, per piece: market 3 000, customer 3 450. */
    private Product $bread;

    protected function setUp(): void
    {
        parent::setUp();

        $this->configure();
        $this->travelTo(CarbonImmutable::parse('2026-09-27 12:00:00', 'Asia/Tashkent'));

        $this->customer = User::factory()->customer()->create(['full_name' => 'Aziza Karimova']);
        $this->address = CustomerAddress::factory()->create(['customer_id' => $this->customer->id]);
        $this->tomatoes = Product::factory()->create(['market_price_uzs' => 16000]);
        $this->bread = Product::factory()->fixed()->unit(UnitCode::Piece)->create(['market_price_uzs' => 3000]);
    }

    public function test_a_checkout_shows_its_lines_amounts_and_a_token_for_five_minutes(): void
    {
        $this->line($this->tomatoes, '3.000');
        $this->line($this->bread, '2.000');

        $data = $this->preview()->assertOk()->json('data');

        $this->assertSame([
            'lines', 'merchandise_subtotal_uzs', 'service_fee_uzs', 'delivery_fee_uzs', 'total_uzs', 'total_kind',
            'payment_method', 'delivery_time_note', 'outside_working_hours', 'opens_at', 'checkout_token', 'checkout_token_expires_at',
        ], array_keys($data));
        $this->assertSame(
            ['cart_item_id', 'product_id', 'name_uz', 'name_ru', 'unit_code', 'quantity', 'price_mode', 'customer_unit_price_uzs', 'line_total_uzs'],
            array_keys($data['lines'][0])
        );
        $this->assertSame([55200, 6900], array_column($data['lines'], 'line_total_uzs'));
        $this->assertSame(['3.000', '2'], array_column($data['lines'], 'quantity'));
        $this->assertSame(62100, $data['merchandise_subtotal_uzs']);
        $this->assertSame(5000, $data['service_fee_uzs']);
        $this->assertSame(15000, $data['delivery_fee_uzs']);
        $this->assertSame(82100, $data['total_uzs']);
        $this->assertSame('estimate', $data['total_kind']);
        $this->assertFalse($data['outside_working_hours']);
        $this->assertSame('08:00', $data['opens_at']);
        $this->assertSame('2026-09-27T07:05:00Z', $data['checkout_token_expires_at']);
        $this->assertStringNotContainsString('market_price', (string) json_encode($data));
    }

    public function test_only_fixed_lines_make_a_final_total_and_a_percentage_fee_follows_the_subtotal(): void
    {
        $this->settings(['service_fee_mode' => 'percentage', 'service_fee_fixed_uzs' => null, 'service_fee_percent' => '3.00', 'minimum_order_uzs' => 0]);
        $this->line($this->bread, '3.000');

        $data = $this->preview()->assertOk()->json('data');

        $this->assertSame('final', $data['total_kind']);
        $this->assertSame(10350, $data['merchandise_subtotal_uzs']);
        $this->assertSame(311, $data['service_fee_uzs'], '3 % of 10 350 = 310.5, half-up.');
        $this->assertSame(25661, $data['total_uzs']);
    }

    public function test_an_order_placed_outside_the_hours_says_when_they_open(): void
    {
        $this->line($this->tomatoes, '3');
        $this->travelTo(CarbonImmutable::parse('2026-09-27 23:00:00', 'Asia/Tashkent'));

        $this->preview()->assertOk()
            ->assertJsonPath('data.outside_working_hours', true)
            ->assertJsonPath('data.opens_at', '08:00');

        $this->settings(['opens_at' => '00:00', 'closes_at' => '23:59']);
        $this->preview()->assertOk()
            ->assertJsonPath('data.outside_working_hours', false)
            ->assertJsonPath('data.opens_at', null);
    }

    public function test_the_settings_are_checked_first(): void
    {
        $this->customer->forceFill(['full_name' => null])->save();
        $this->settings(['delivery_fee_uzs' => null]);

        $this->preview()->assertStatus(409)->assertJsonPath('code', 'checkout_configuration_incomplete');

        foreach ([
            ['opens_at' => null, 'closes_at' => null],
            ['service_radius_km' => null],
            ['service_fee_fixed_uzs' => null],
            ['minimum_order_uzs' => null],
            ['service_fee_mode' => 'percentage', 'service_fee_fixed_uzs' => null, 'service_fee_percent' => null],
        ] as $missing) {
            $this->configure();
            $this->settings($missing);
            $this->preview()->assertStatus(409)->assertJsonPath('code', 'checkout_configuration_incomplete');
        }
    }

    public function test_a_customer_without_a_name_is_told_so_before_the_cart(): void
    {
        $this->customer->forceFill(['full_name' => '   '])->save();

        $this->preview()->assertStatus(409)->assertJsonPath('code', 'customer_profile_incomplete');
    }

    public function test_the_address_is_the_customers_own_active_one_inside_the_area(): void
    {
        $this->line($this->tomatoes, '3');
        $foreign = CustomerAddress::factory()->create();
        $inactive = CustomerAddress::factory()->inactive()->create(['customer_id' => $this->customer->id]);
        $far = CustomerAddress::factory()->create(['customer_id' => $this->customer->id, 'latitude' => '41.550000', 'longitude' => '69.600000']);

        foreach ([$foreign->id, $inactive->id, (string) Str::uuid()] as $id) {
            $this->preview(['address_id' => $id])->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        }
        $this->preview(['address_id' => $far->id])->assertStatus(422)
            ->assertJsonPath('code', 'address_outside_service_area')
            ->assertJsonPath('details.max_distance_km', '5.00');
    }

    public function test_an_empty_cart_is_refused(): void
    {
        $this->preview()->assertStatus(409)->assertJsonPath('code', 'cart_empty');
    }

    public function test_a_line_whose_product_is_gone_or_whose_unit_changed_is_refused(): void
    {
        $this->line($this->tomatoes, '1.500');
        $this->line($this->bread, '20.000');
        $gone = Product::factory()->create();
        $this->line($gone, '5.000');
        Product::query()->whereKey($gone->id)->update(['is_active' => false]);
        Product::query()->whereKey($this->tomatoes->id)->update(['unit_code' => 'piece']);

        $this->preview()->assertStatus(409)
            ->assertJsonPath('code', 'product_unavailable')
            ->assertJsonPath('details.product_ids', [$this->tomatoes->id, $gone->id]);
    }

    public function test_the_minimum_is_checked_on_the_merchandise_and_names_the_shortfall(): void
    {
        $this->line($this->bread, '10.000');

        $this->preview()->assertStatus(409)
            ->assertJsonPath('code', 'minimum_order_not_reached')
            ->assertJsonPath('details.minimum_order_uzs', 50000)
            ->assertJsonPath('details.shortfall_uzs', 15500);
    }

    public function test_online_payment_is_unavailable_whatever_the_switches_say(): void
    {
        $this->line($this->tomatoes, '3');
        DB::table('payment_provider_settings')->update(['is_enabled' => true]);

        $this->preview(['payment_method' => 'online'])->assertStatus(409)->assertJsonPath('code', 'payment_method_unavailable');
    }

    public function test_the_request_is_held_to_its_shape_and_staff_are_refused(): void
    {
        $this->line($this->tomatoes, '3');

        $this->preview(['address_id' => null])->assertStatus(422);
        $this->preview(['payment_method' => 'card'])->assertStatus(422);
        $this->preview(['delivery_time_note' => str_repeat('a', 161)])->assertStatus(422);
        $this->preview(['total_uzs' => 1])->assertStatus(422);
        $this->preview(['delivery_time_note' => 'После 18:00'])->assertOk()->assertJsonPath('data.delivery_time_note', 'После 18:00');

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)->postJson(self::URL, $this->body())->assertStatus(403);
    }

    public function test_the_token_is_the_customers_for_five_minutes_and_cannot_be_altered(): void
    {
        $this->line($this->tomatoes, '3');
        $token = (string) $this->preview()->json('data.checkout_token');

        $claims = CheckoutToken::read($token, $this->customer, now());
        $this->assertSame($this->address->id, $claims->addressId);
        $this->assertSame(PaymentMethod::Cash, $claims->paymentMethod);
        $this->assertSame(CustomerCart::of($this->customer)->id, $claims->cartId);

        $other = User::factory()->customer()->create();
        [$payload, $signature] = explode('.', $token);
        $forgedPayload = rtrim(strtr(base64_encode((string) str_replace(
            $this->address->id,
            (string) Str::uuid(),
            (string) base64_decode(strtr($payload, '-_', '+/'))
        )), '+/', '-_'), '=');

        foreach ([
            fn () => CheckoutToken::read($token, $other, now()),
            fn () => CheckoutToken::read($token, $this->customer, now()->addSeconds(CheckoutToken::TTL_SECONDS)),
            fn () => CheckoutToken::read($forgedPayload.'.'.$signature, $this->customer, now()),
            fn () => CheckoutToken::read($payload.'.'.strrev($signature), $this->customer, now()),
            fn () => CheckoutToken::read('not-a-token', $this->customer, now()),
            fn () => CheckoutToken::read($payload.'.'.$signature.'.x', $this->customer, now()),
        ] as $attempt) {
            try {
                $attempt();
                $this->fail('A token that should be stale was read.');
            } catch (ApiException $stale) {
                $this->assertSame('checkout_snapshot_stale', $stale->apiCode());
            }
        }

        $this->assertSame(
            $this->address->id,
            CheckoutToken::read($token, $this->customer, now()->addSeconds(CheckoutToken::TTL_SECONDS - 1))->addressId,
            'A second before the expiry the token still reads.'
        );
    }

    public function test_any_change_to_what_the_order_would_snapshot_changes_the_digest(): void
    {
        $line = $this->line($this->tomatoes, '3.000');
        $shown = CheckoutToken::read((string) $this->preview()->json('data.checkout_token'), $this->customer, now())->digest;
        $this->assertSame($shown, $this->digest(), 'Nothing changed, nothing is stale.');

        $changes = [
            'the quantity' => fn () => $line->forceFill(['quantity' => '4.000'])->save(),
            'the market price' => fn () => Product::query()->whereKey($this->tomatoes->id)->update(['market_price_uzs' => 17000]),
            'the markup' => fn () => $this->settings(['markup_percent' => '16.00']),
            'the service fee' => fn () => $this->settings(['service_fee_fixed_uzs' => 6000]),
            'the delivery fee' => fn () => $this->settings(['delivery_fee_uzs' => 16000]),
            'the tolerance' => fn () => $this->settings(['price_tolerance_percent' => '20.00']),
            'the address point' => fn () => $this->address->forceFill(['latitude' => '41.312000'])->save(),
            'the note' => fn () => $line->forceFill(['customer_note' => 'Qizil'])->save(),
            'the rule' => fn () => $line->forceFill(['substitution_policy' => 'remove_if_unavailable'])->save(),
            'the name' => fn () => $this->customer->forceFill(['full_name' => 'Aziza K.'])->save(),
            'the unit, to one the quantity still fits' => fn () => Product::query()->whereKey($this->tomatoes->id)->update(['unit_code' => 'piece']),
            'a line added' => fn () => $this->line($this->bread, '20.000'),
            'the line removed and another added' => function () use ($line): void {
                $line->delete();
                $this->line($this->bread, '20.000');
            },
            'the product name' => fn () => Product::query()->whereKey($this->tomatoes->id)->update(['name_ru' => 'Томаты']),
            'the price mode' => fn () => Product::query()->whereKey($this->tomatoes->id)->update(['price_mode' => 'fixed']),
            'the street' => fn () => $this->address->forceFill(['street' => 'Navoiy'])->save(),
            'the house' => fn () => $this->address->forceFill(['house' => '14'])->save(),
            'the apartment' => fn () => $this->address->forceFill(['apartment' => '7'])->save(),
            'the landmark' => fn () => $this->address->forceFill(['landmark' => 'Maktab'])->save(),
            'the delivery note' => fn () => $this->address->forceFill(['delivery_note' => 'Domofon 7'])->save(),
            'the fee mode' => fn () => $this->settings(['service_fee_mode' => 'percentage', 'service_fee_fixed_uzs' => null, 'service_fee_percent' => '8.00']),
            'the delay threshold' => fn () => $this->settings(['delivery_delay_threshold_minutes' => 90]),
        ];

        foreach ($changes as $what => $change) {
            DB::beginTransaction();
            $change();
            $this->assertNotSame($shown, $this->digest(), "Changing {$what} must make the token stale.");
            DB::rollBack();
            $this->customer->refresh();
            $this->address->refresh();
            $line->refresh();
        }

        $this->assertNotSame($shown, $this->digest('Kechqurun'), 'A different delivery wish is a different checkout.');
    }

    public function test_the_digest_is_keyed_so_the_hidden_prices_cannot_be_recovered_from_it(): void
    {
        $this->line($this->tomatoes, '3.000');
        $underThisKey = $this->digest();

        config(['app.key' => 'base64:'.base64_encode(random_bytes(32))]);

        $this->assertNotSame($underThisKey, $this->digest(), 'DL-41 (7): the digest depends on a secret.');
    }

    public function test_a_token_signed_under_another_key_is_stale(): void
    {
        $this->line($this->tomatoes, '3');
        $token = (string) $this->preview()->json('data.checkout_token');

        config(['app.key' => 'base64:'.base64_encode(random_bytes(32))]);

        $this->expectExceptionObject(CheckoutToken::stale());
        CheckoutToken::read($token, $this->customer, now());
    }

    public function test_a_signature_has_one_spelling(): void
    {
        $this->line($this->tomatoes, '3');
        $token = (string) $this->preview()->json('data.checkout_token');

        // The last character of a 43-character base64 signature carries two
        // spare bits; flipping one spells the same bytes differently.
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
        $last = strpos($alphabet, $token[strlen($token) - 1]);
        $this->assertIsInt($last);
        $respelt = substr($token, 0, -1).$alphabet[$last ^ 1];

        try {
            CheckoutToken::read($respelt, $this->customer, now());
            $this->fail('A second spelling of the signature was read.');
        } catch (ApiException $stale) {
            $this->assertSame('checkout_snapshot_stale', $stale->apiCode());
        }
    }

    public function test_an_application_key_that_cannot_be_read_fails_closed(): void
    {
        foreach (['base64:', 'base64:%%%', ''] as $broken) {
            config(['app.key' => $broken]);

            try {
                CheckoutSecrets::key(CheckoutSecrets::SIGNING);
                $this->fail("The key \"{$broken}\" was used.");
            } catch (LogicException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    private function digest(?string $note = null): string
    {
        return CheckoutState::gather(
            $this->customer->fresh() ?? $this->customer,
            CustomerCart::of($this->customer),
            $this->address->id,
            PaymentMethod::Cash,
            $note,
        )->digest();
    }

    private function line(Product $product, string $quantity): CartItem
    {
        return CartItem::factory()->create([
            'cart_id' => CustomerCart::of($this->customer)->id,
            'product_id' => $product->id,
            'quantity' => $quantity,
        ]);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function body(array $overrides = []): array
    {
        return array_merge(['address_id' => $this->address->id, 'payment_method' => 'cash'], $overrides);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function preview(array $overrides = []): TestResponse
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken)->postJson(self::URL, $this->body($overrides));
    }

    private function configure(): void
    {
        $this->settings([
            'markup_percent' => '15.00',
            'service_fee_mode' => 'fixed',
            'service_fee_fixed_uzs' => 5000,
            'service_fee_percent' => null,
            'delivery_fee_uzs' => 15000,
            'minimum_order_uzs' => 50000,
            'price_tolerance_percent' => '15.00',
            'opens_at' => '08:00',
            'closes_at' => '22:00',
            'service_centre_latitude' => '41.311081',
            'service_centre_longitude' => '69.240562',
            'service_radius_km' => '5.00',
        ]);
    }

    /**
     * @param  array<string, mixed>  $values
     */
    private function settings(array $values): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update($values);
    }
}
