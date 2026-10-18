<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `POST /customer/orders/{order}/rating` (`docs/09` section 59, `DL-90` (1),
 * `DL-91` (4)): one rating for a delivered order, within seven days.
 */
final class OrderRatingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_customer_rates_a_delivered_order(): void
    {
        $order = Order::factory()->completed()->create();

        $response = $this->rate($order, ['stars' => 2, 'reasons' => ['not_fresh', 'late'], 'comment' => '  Помидоры мятые  '])->assertCreated();

        $rating = $response->json('data.rating');
        $this->assertSame(['stars', 'reasons', 'comment', 'created_at'], array_keys($rating));
        $this->assertSame(2, $rating['stars']);
        $this->assertSame(['not_fresh', 'late'], $rating['reasons']);
        $this->assertSame('Помидоры мятые', $rating['comment']);
        $this->assertNotFalse(strtotime((string) $rating['created_at']));
        $response->assertJsonPath('data.can_rate', false);

        $row = collect($this->as($order->customer)->getJson('/api/v1/customer/orders?state=past')->assertOk()->json('data'))->firstWhere('id', $order->id);
        $this->assertSame(2, $row['rating_stars']);
        $this->assertFalse($row['can_rate']);
        $this->as($order->customer)->getJson("/api/v1/customer/orders/{$order->id}")->assertOk()->assertJsonPath('data.rating.stars', 2);
    }

    public function test_an_unrated_delivered_order_can_be_rated(): void
    {
        $order = Order::factory()->completed()->create();

        $this->as($order->customer)->getJson("/api/v1/customer/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.rating', null)
            ->assertJsonPath('data.can_rate', true);

        $row = collect($this->as($order->customer)->getJson('/api/v1/customer/orders?state=past')->json('data'))->firstWhere('id', $order->id);
        $this->assertNull($row['rating_stars']);
        $this->assertTrue($row['can_rate']);
    }

    public function test_an_identical_repeat_is_answered_and_a_different_one_refused(): void
    {
        $order = Order::factory()->completed()->create();
        $body = ['stars' => 2, 'reasons' => ['not_fresh', 'late'], 'comment' => 'Мятые'];

        $this->rate($order, $body)->assertCreated();
        $this->rate($order, ['stars' => 2, 'reasons' => ['late', 'not_fresh'], 'comment' => ' Мятые '])
            ->assertOk()
            ->assertJsonPath('data.rating.stars', 2);
        $this->assertSame(1, DB::table('order_ratings')->count());

        $this->rate($order, ['stars' => 5])->assertStatus(409)->assertJsonPath('code', 'order_already_rated');
        $this->assertSame(2, (int) DB::table('order_ratings')->value('stars'));
    }

    public function test_only_a_completed_order_within_seven_days_is_rateable(): void
    {
        $this->travelTo(now()->startOfSecond());

        $onTheWay = Order::factory()->onTheWay()->create();
        $this->rate($onTheWay, ['stars' => 5])->assertStatus(409)->assertJsonPath('code', 'order_not_rateable');

        $cancelled = Order::factory()->cancelled()->create();
        $this->rate($cancelled, ['stars' => 5])->assertStatus(409)->assertJsonPath('code', 'order_not_rateable');

        $edge = Order::factory()->completed()->create();
        $edge->forceFill(['completed_at' => now()->subDays(7)])->save();
        $this->rate($edge, ['stars' => 5])->assertCreated();

        $late = Order::factory()->completed()->create();
        $late->forceFill(['completed_at' => now()->subDays(7)->subSecond()])->save();
        $this->rate($late, ['stars' => 5])->assertStatus(409)->assertJsonPath('code', 'rating_window_closed');
        $this->as($late->customer)->getJson("/api/v1/customer/orders/{$late->id}")->assertJsonPath('data.can_rate', false);

        $this->assertSame(1, DB::table('order_ratings')->count());
    }

    public function test_the_body_is_validated(): void
    {
        $order = Order::factory()->completed()->create();

        foreach ([0, 6, '3', null] as $stars) {
            $this->rate($order, ['stars' => $stars])->assertStatus(422)->assertJsonValidationErrors('stars');
        }
        $this->rate($order, [])->assertStatus(422)->assertJsonValidationErrors('stars');
        $this->rate($order, ['stars' => 4, 'reasons' => ['late']])->assertStatus(422)->assertJsonValidationErrors('reasons');
        $this->rate($order, ['stars' => 2, 'reasons' => ['bad']])->assertStatus(422)->assertJsonValidationErrors('reasons.0');
        $this->rate($order, ['stars' => 2, 'reasons' => ['late', 'late']])->assertStatus(422)->assertJsonValidationErrors('reasons.0');
        $this->rate($order, ['stars' => 2, 'comment' => str_repeat('я', 501)])->assertStatus(422)->assertJsonValidationErrors('comment');
        $this->rate($order, ['stars' => 2, 'extra' => 1])->assertStatus(422);
        $this->assertSame(0, DB::table('order_ratings')->count());

        $this->rate($order, ['stars' => 5, 'comment' => "  \n "])->assertCreated()->assertJsonPath('data.rating.comment', null);
        $this->assertNull(DB::table('order_ratings')->value('comment'));
    }

    public function test_another_customer_cannot_rate(): void
    {
        $order = Order::factory()->completed()->create();
        $other = User::factory()->customer()->create();

        $this->as($other)->postJson("/api/v1/customer/orders/{$order->id}/rating", ['stars' => 1])
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
        $this->assertSame(0, DB::table('order_ratings')->count());
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function rate(Order $order, array $body): TestResponse
    {
        return $this->as($order->customer)->postJson("/api/v1/customer/orders/{$order->id}/rating", $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
