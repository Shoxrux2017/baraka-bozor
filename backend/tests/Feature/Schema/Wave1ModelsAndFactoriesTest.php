<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\BusinessSettings;
use App\Models\Category;
use App\Models\CustomerAddress;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PriceMode;
use App\Models\Enums\PushPlatform;
use App\Models\Enums\Role;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Enums\UnitCode;
use App\Models\PaymentProviderSetting;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The models and factories of the Wave 1 tables: every factory produces a row
 * the database accepts, every state keeps the row consistent, and the casts
 * hand back the enums and strings the rest of the wave relies on.
 */
final class Wave1ModelsAndFactoriesTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_category_and_a_product_are_created_by_an_admin_with_the_expected_casts(): void
    {
        $product = Product::factory()->create();

        $this->assertSame(Role::Admin, User::query()->findOrFail($product->created_by_user_id)->role);
        $this->assertSame(Role::Admin, User::query()->findOrFail($product->category->created_by_user_id)->role);
        $this->assertSame($product->id, $product->category->products()->first()?->id);
        $this->assertSame(UnitCode::Kg, $product->unit_code);
        $this->assertSame(PriceMode::Estimate, $product->price_mode);
        $this->assertSame(16000, $product->market_price_uzs);
        $this->assertTrue($product->is_active);
        $this->assertNull($product->archived_at);
        $this->assertNull($product->image);
    }

    public function test_the_factory_states_keep_a_row_consistent(): void
    {
        $archivedCategory = Category::factory()->archived()->create();
        $this->assertFalse($archivedCategory->is_active);
        $this->assertNotNull($archivedCategory->archived_at);

        $fixedBox = Product::factory()->fixed()->unit(UnitCode::Box)->archived()->create();
        $this->assertSame(PriceMode::Fixed, $fixedBox->price_mode);
        $this->assertSame(UnitCode::Box, $fixedBox->unit_code);
        $this->assertFalse($fixedBox->unit_code->acceptsDecimals());
        $this->assertFalse($fixedBox->is_active);

        $image = ProductImage::factory()->create();
        $this->assertSame($image->id, $image->product->image?->id);
        $this->assertSame('image/webp', $image->mime_type);

        $address = CustomerAddress::factory()->inactive()->create();
        $this->assertFalse($address->is_active);
        $this->assertSame(Role::Customer, $address->customer->role);
        $this->assertSame('41.311081', $address->latitude);

        $device = PushDevice::factory()->revoked()->create();
        $this->assertSame(PushPlatform::Android, $device->platform);
        $this->assertNotNull($device->revoked_at);
        $this->assertSame($device->user_id, $device->user->id);
    }

    public function test_the_settings_singleton_and_the_providers_are_there_without_a_factory(): void
    {
        $settings = BusinessSettings::current();

        $this->assertSame(1, $settings->id);
        $this->assertSame('0.00', $settings->markup_percent);
        $this->assertSame(ServiceFeeMode::Fixed, $settings->service_fee_mode);
        $this->assertSame('15.00', $settings->price_tolerance_percent);
        $this->assertSame(60, $settings->delivery_delay_threshold_minutes);
        $this->assertNull($settings->service_radius_km);

        $providers = PaymentProviderSetting::query()->orderBy('provider')->get();
        $this->assertSame(
            [PaymentProvider::Click, PaymentProvider::Payme, PaymentProvider::Paynet, PaymentProvider::Xazna],
            $providers->pluck('provider')->all()
        );
        $this->assertFalse($providers->contains(fn (PaymentProviderSetting $setting): bool => $setting->is_enabled));
    }

    public function test_the_units_that_take_decimals_are_exactly_kg_liter_and_meter(): void
    {
        $decimal = array_map(
            static fn (UnitCode $unit): string => $unit->value,
            array_values(array_filter(UnitCode::cases(), static fn (UnitCode $unit): bool => $unit->acceptsDecimals()))
        );

        $this->assertSame(['kg', 'liter', 'meter'], $decimal, 'BR-QTY-001');
    }
}
