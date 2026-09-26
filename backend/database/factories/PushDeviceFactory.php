<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\PushPlatform;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * Builds push devices the database will accept, for an account created on
 * demand.
 *
 * @extends Factory<PushDevice>
 */
final class PushDeviceFactory extends Factory
{
    protected $model = PushDevice::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory()->customer(),
            'platform' => PushPlatform::Android,
            'push_token' => 'fcm-'.Str::random(64),
            'last_seen_at' => now(),
            'revoked_at' => null,
        ];
    }

    public function revoked(): self
    {
        return $this->state(fn (): array => ['revoked_at' => now()]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): PushDevice
    {
        return (new PushDevice)->forceFill($attributes);
    }
}
