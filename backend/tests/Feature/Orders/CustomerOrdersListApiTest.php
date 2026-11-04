<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * The Customer's order list: the current and past tabs, the address and the
 * picture of a row, the picture of a detail line (`docs/09` section 20,
 * `DL-90`, `DL-91` (1)).
 */
final class CustomerOrdersListApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_state_current_and_past_split_the_list(): void
    {
        $customer = User::factory()->customer()->create();
        $new = Order::factory()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(4)]);
        $onTheWay = Order::factory()->onTheWay()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(3)]);
        $completed = Order::factory()->completed()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(2)]);
        $cancelled = Order::factory()->cancelled()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinute()]);

        $this->assertSame(
            [$onTheWay->id, $new->id],
            array_column($this->as($customer)->getJson('/api/v1/customer/orders?state=current')->assertOk()->json('data'), 'id'),
        );
        $this->assertSame(
            [$cancelled->id, $completed->id],
            array_column($this->as($customer)->getJson('/api/v1/customer/orders?state=past')->assertOk()->json('data'), 'id'),
        );
        $this->assertCount(4, $this->as($customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data'));

        $this->as($customer)->getJson('/api/v1/customer/orders?state=old')
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('state', 'errors');
    }

    public function test_a_row_carries_the_address_street_and_house(): void
    {
        $order = Order::factory()->create();

        $row = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0');

        $this->assertSame(['street' => $order->street_snapshot, 'house' => $order->house_snapshot], $row['address']);
    }

    public function test_a_row_pictures_the_earliest_line_with_a_picture(): void
    {
        $order = Order::factory()->create();
        $this->line($order, null, now()->subMinutes(3));
        $this->line($order, 'products/b.webp', now()->subMinutes(2));
        $this->line($order, 'products/c.webp', now()->subMinute());
        $bare = Order::factory()->create(['customer_id' => $order->customer_id, 'created_at' => now()->subHour()]);
        $this->line($bare, null, now());

        $rows = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data');
        $byId = array_column($rows, null, 'id');

        $this->assertStringEndsWith('products/b.webp', $byId[$order->id]['image_url']);
        $this->assertNull($byId[$bare->id]['image_url']);
    }

    public function test_a_row_prefers_a_line_that_is_not_removed(): void
    {
        $order = Order::factory()->create();
        $this->line($order, 'products/tomato.webp', now()->subMinutes(2), ItemRemovedReason::CustomerRemoved);
        $this->line($order, 'products/bread.webp', now()->subMinute());

        $allRemoved = Order::factory()->cancelled()->create(['customer_id' => $order->customer_id, 'created_at' => now()->subHour()]);
        $this->line($allRemoved, 'products/second.webp', now()->subMinute(), ItemRemovedReason::OrderCancelled);
        $this->line($allRemoved, 'products/first.webp', now()->subMinutes(2), ItemRemovedReason::OrderCancelled);

        $byId = array_column($this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data'), null, 'id');

        $this->assertStringEndsWith('products/bread.webp', $byId[$order->id]['image_url']);
        $this->assertStringEndsWith('products/first.webp', $byId[$allRemoved->id]['image_url']);
    }

    public function test_detail_lines_carry_their_product_picture(): void
    {
        $order = Order::factory()->create();
        $this->line($order, 'products/with.webp', now()->subMinute());
        $this->line($order, null, now());

        $items = $this->as($order->customer)->getJson("/api/v1/customer/orders/{$order->id}")->assertOk()->json('data.items');

        $this->assertStringEndsWith('products/with.webp', $items[0]['image_url']);
        $this->assertNull($items[1]['image_url']);
    }

    public function test_another_customers_orders_are_not_listed(): void
    {
        $mine = Order::factory()->create();
        $theirs = Order::factory()->create();
        $theirsDone = Order::factory()->completed()->create();

        foreach (['current', 'past'] as $state) {
            $ids = array_column($this->as($mine->customer)->getJson("/api/v1/customer/orders?state={$state}")->assertOk()->json('data'), 'id');
            $this->assertNotContains($theirs->id, $ids);
            $this->assertNotContains($theirsDone->id, $ids);
        }
    }

    public function test_the_summary_lists_the_open_questions_expiries_earliest_first(): void
    {
        $this->freezeTime();
        $order = Order::factory()->shopping()->create();
        $this->question($order, now()->addMinutes(9));
        $this->question($order, now()->addMinutes(4));
        $this->question($order, now()->subMinute());
        $this->question($order, now()->addMinutes(6), ApprovalStatus::Approved);
        $this->question(Order::factory()->shopping()->create(), now()->addMinutes(2));
        $quiet = Order::factory()->create(['customer_id' => $order->customer_id, 'created_at' => now()->subHour()]);

        $byId = array_column($this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data'), null, 'id');

        $this->assertSame(
            [now()->addMinutes(4)->toIso8601ZuluString(), now()->addMinutes(9)->toIso8601ZuluString()],
            $byId[$order->id]['pending_approval_expires_at'],
        );
        $this->assertSame(2, $byId[$order->id]['pending_approval_count']);
        $this->assertSame([], $byId[$quiet->id]['pending_approval_expires_at']);
    }

    public function test_the_question_count_and_the_expiries_come_from_one_read(): void
    {
        $this->freezeTime();
        $order = Order::factory()->shopping()->create();
        $this->question($order, now()->addMinutes(9));
        $this->question($order, now()->addMinutes(4));
        $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk();

        DB::flushQueryLog();
        DB::enableQueryLog();
        $row = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0');
        $reads = array_filter(
            array_column(DB::getQueryLog(), 'query'),
            static fn (string $sql): bool => str_contains($sql, 'customer_approvals'),
        );
        DB::disableQueryLog();

        $this->assertCount(1, $reads, 'a question asked or expired between two reads would split the count from the expiries');
        $this->assertCount(2, $row['pending_approval_expires_at']);
        $this->assertSame(count($row['pending_approval_expires_at']), $row['pending_approval_count']);
    }

    public function test_the_preview_names_the_first_lines_and_counts_them(): void
    {
        $order = Order::factory()->create();
        $lines = [];
        foreach (range(1, 10) as $n) {
            $removed = match ($n) {
                3 => ItemRemovedReason::Unavailable,
                5 => ItemRemovedReason::CustomerRemoved,
                default => null,
            };
            $lines[$n] = $this->line($order, $n === 2 ? null : "products/p{$n}.webp", now()->subMinutes(20 - $n), $removed);
        }

        $preview = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0.preview');

        $this->assertSame(8, $preview['line_count']);
        $this->assertCount(4, $preview['lines']);
        foreach ([1, 2, 4, 6] as $i => $n) {
            $this->assertSame($lines[$n]->product_name_uz_snapshot, $preview['lines'][$i]['name_uz']);
            $this->assertSame($lines[$n]->product_name_ru_snapshot, $preview['lines'][$i]['name_ru']);
        }
        $this->assertNull($preview['lines'][1]['image_url']);
        foreach ([0 => 1, 2 => 4, 3 => 6] as $i => $n) {
            $this->assertStringEndsWith("products/p{$n}.webp", $preview['lines'][$i]['image_url']);
        }
    }

    public function test_every_order_of_a_page_gets_its_own_preview_lines(): void
    {
        $customer = User::factory()->customer()->create();
        $first = [];
        $counts = [];
        foreach (range(1, 20) as $n) {
            $order = Order::factory()->shopping()->create(['customer_id' => $customer->id]);
            $counts[$order->id] = ($n % 7) + 1;
            foreach (range(1, $counts[$order->id]) as $m) {
                $line = $this->line($order, null, now()->subMinutes(100 - $m));
                $first[$order->id] ??= $line;
            }
        }

        $rows = $this->as($customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data');

        $this->assertCount(20, $rows);
        foreach ($rows as $row) {
            $preview = $row['preview'];
            $this->assertSame($counts[$row['id']], $preview['line_count']);
            $this->assertCount(min($preview['line_count'], 4), $preview['lines']);
            $this->assertSame($first[$row['id']]->product_name_ru_snapshot, $preview['lines'][0]['name_ru']);
        }
    }

    public function test_a_cancelled_order_previews_its_lines_but_the_customers_own_removals(): void
    {
        $order = Order::factory()->cancelled()->create();
        $this->line($order, null, now()->subMinutes(3), ItemRemovedReason::CustomerRemoved);
        $this->line($order, null, now()->subMinutes(2), ItemRemovedReason::OrderCancelled);
        $this->line($order, null, now()->subMinute(), ItemRemovedReason::OrderCancelled);

        $preview = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0.preview');

        $this->assertSame(2, $preview['line_count']);
        $this->assertCount(2, $preview['lines']);
    }

    public function test_the_list_queries_do_not_grow_with_its_orders(): void
    {
        $small = Order::factory()->create();
        $this->line($small, 'products/a.webp', now());
        $this->line($small, null, now());
        $this->question($small, now()->addMinutes(5));
        $few = $this->queriesOfTheList($small->customer);

        $big = User::factory()->customer()->create();
        foreach (range(1, 20) as $n) {
            $order = Order::factory()->shopping()->create(['customer_id' => $big->id]);
            foreach (range(1, 12) as $m) {
                $this->line($order, $m % 2 === 0 ? "products/{$n}-{$m}.webp" : null, now()->subSeconds(60 - $m));
            }
            $this->question($order, now()->addMinutes($n));
        }

        $this->assertSame($few, $this->queriesOfTheList($big));
    }

    private function queriesOfTheList(User $customer): int
    {
        $this->as($customer)->getJson('/api/v1/customer/orders')->assertOk();
        DB::flushQueryLog();
        DB::enableQueryLog();
        $this->as($customer)->getJson('/api/v1/customer/orders')->assertOk();
        $count = count(DB::getQueryLog());
        DB::disableQueryLog();

        return $count;
    }

    private function question(Order $order, \DateTimeInterface $expires, ApprovalStatus $status = ApprovalStatus::Pending): CustomerApproval
    {
        $item = OrderItem::factory()->awaitingCustomer()->create(['order_id' => $order->id]);

        $factory = $status === ApprovalStatus::Approved ? CustomerApproval::factory()->approved() : CustomerApproval::factory();

        return $factory->create([
            'order_item_id' => $item->id,
            'order_id' => $order->id,
            'attention_at' => Carbon::instance($expires)->subMinutes(10),
            'expires_at' => $expires,
        ]);
    }

    private function line(Order $order, ?string $key, \DateTimeInterface $at, ?ItemRemovedReason $removed = null): OrderItem
    {
        $product = Product::factory()->create();

        if ($key !== null) {
            ProductImage::factory()->create(['product_id' => $product->id, 'storage_key' => $key]);
        }

        $factory = OrderItem::factory();

        return ($removed === null ? $factory : $factory->removed($removed))
            ->create(['order_id' => $order->id, 'product_id' => $product->id, 'created_at' => $at]);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
