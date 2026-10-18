<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderRating;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Operator's review of a low rating, `docs/09` section 60 and `DL-91` (5).
 */
final class RatingReviewApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_operator_reviews_a_rating(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $admin = User::factory()->role(Role::Admin)->create();
        $rating = OrderRating::factory()->low()->create();
        $order = $rating->order_id;

        $this->as($operator)->getJson('/api/v1/operations/attention')->assertJsonPath('data.0.type', 'low_rating');

        $data = $this->review($operator, $order)->assertOk()->json('data');
        $this->assertSame($order, $data['id']);
        $this->assertSame(['id' => $operator->id, 'full_name' => $operator->full_name], $data['rating']['reviewed_by']);
        $this->assertNotNull($data['rating']['reviewed_at']);
        $this->assertSame([], $this->as($operator)->getJson('/api/v1/operations/attention')->json('data'));

        $again = $this->review($admin, $order)->assertOk()->json('data');
        $this->assertSame($operator->id, $again['rating']['reviewed_by']['id']);
        $this->assertSame($data['rating']['reviewed_at'], $again['rating']['reviewed_at']);
    }

    public function test_reviewing_an_unrated_order_is_refused(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $order = Order::factory()->completed()->create();

        $this->review($operator, $order->id)->assertStatus(409)->assertJsonPath('code', 'order_not_rated');
        $this->review($operator, (string) Str::uuid())->assertStatus(404);
    }

    public function test_only_operators_and_admins_review(): void
    {
        $rating = OrderRating::factory()->low()->create();

        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $this->review(User::factory()->role($role)->create(), $rating->order_id)->assertStatus(403);
        }
        $this->as(User::factory()->role(Role::Operator)->create())
            ->postJson('/api/v1/operations/orders/'.$rating->order_id.'/rating/review', ['note' => 'x'])
            ->assertStatus(422);
        $this->assertNull($rating->fresh()?->reviewed_at);
    }

    public function test_the_board_order_shows_the_rating(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $rating = OrderRating::factory()->create(['stars' => 2, 'reasons' => ['late'], 'comment' => 'Cold']);

        $shown = $this->as($operator)->getJson('/api/v1/operations/orders/'.$rating->order_id)->assertOk()->json('data.rating');

        $this->assertSame(2, $shown['stars']);
        $this->assertSame(['late'], $shown['reasons']);
        $this->assertSame('Cold', $shown['comment']);
        $this->assertNull($shown['reviewed_by']);
        $this->assertNull($shown['reviewed_at']);
        $this->assertNotNull($shown['created_at']);

        $unrated = Order::factory()->completed()->create();
        $this->as($operator)->getJson('/api/v1/operations/orders/'.$unrated->id)->assertOk()->assertJsonPath('data.rating', null);
    }

    private function review(User $user, string $order): TestResponse
    {
        return $this->as($user)->postJson('/api/v1/operations/orders/'.$order.'/rating/review');
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
