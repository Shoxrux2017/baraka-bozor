<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\CustomerAddress;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds addresses the database will accept, owned by a Customer created on
 * demand. The default point is in central Tashkent; a test about the service
 * area moves it.
 *
 * @extends Factory<CustomerAddress>
 */
final class CustomerAddressFactory extends Factory
{
    protected $model = CustomerAddress::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'customer_id' => User::factory()->customer(),
            'label' => 'Uy',
            'latitude' => '41.311081',
            'longitude' => '69.240562',
            'street' => 'Amir Temur shoh ko\'chasi',
            'house' => '12',
            'apartment' => null,
            'landmark' => null,
            'delivery_note' => null,
            'is_active' => true,
        ];
    }

    public function inactive(): self
    {
        return $this->state(fn (): array => ['is_active' => false]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): CustomerAddress
    {
        return (new CustomerAddress)->forceFill($attributes);
    }
}
