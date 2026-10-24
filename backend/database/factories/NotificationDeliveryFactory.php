<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\NotificationType;
use App\Models\NotificationDelivery;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds queued delivery rows the database will accept, for an account created
 * on demand.
 *
 * @extends Factory<NotificationDelivery>
 */
final class NotificationDeliveryFactory extends Factory
{
    protected $model = NotificationDelivery::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory()->customer(),
            'push_device_id' => null,
            'order_id' => null,
            'approval_id' => null,
            'type' => NotificationType::OrderAccepted,
            'status' => NotificationDeliveryStatus::Queued,
            'attempt_count' => 0,
            'sent_at' => null,
            'last_error_code' => null,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): NotificationDelivery
    {
        return (new NotificationDelivery)->forceFill($attributes);
    }
}
