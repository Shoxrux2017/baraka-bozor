<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `order_ratings`, as `docs/08-database.md` Section 33 names it: one rating
 * per order (`BR-RATE-001`), reasons only at 1 to 3 stars (`BR-RATE-002`), and
 * a review that names its reviewer and its time together (`BR-RATE-003`).
 */
final class OrderRatingsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_ratings';

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->order = Order::factory()->completed()->create();
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => $this->order->id,
            'customer_id' => $this->order->customer_id,
            'stars' => 5,
            'reasons' => '[]',
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'customer_id' => ['uuid', false],
            'stars' => ['smallint', false],
            'reasons' => ['jsonb', false],
            'comment' => ['character varying', true, 500],
            'reviewed_by_user_id' => ['uuid', true],
            'reviewed_at' => ['timestamp with time zone', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);
    }

    public function test_the_stars_are_one_to_five(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_ratings_stars_check', $this->row(['stars' => 0]), 'DL-90 (1): 1 to 5 stars.');
        $this->assertRejectedBy(self::TABLE, 'order_ratings_stars_check', $this->row(['stars' => 6]), 'DL-90 (1): 1 to 5 stars.');
    }

    public function test_reasons_belong_to_a_low_rating_only(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_ratings_reasons_check',
            $this->row(['stars' => 4, 'reasons' => '["late"]']),
            'BR-RATE-002: reasons only at 1 to 3 stars.'
        );

        DB::table(self::TABLE)->insert($this->row(['stars' => 3, 'reasons' => '["late"]']));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_reasons_are_a_json_array(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_ratings_reasons_type_check',
            $this->row(['stars' => 2, 'reasons' => '{}']),
            'The reasons are a list, not an object.'
        );
    }

    public function test_an_order_has_one_rating(): void
    {
        DB::table(self::TABLE)->insert($this->row());

        $this->assertRejectedBy(self::TABLE, 'order_ratings_order_id_unique', $this->row(['stars' => 4]), 'BR-RATE-001: one rating per order.');
    }

    public function test_a_review_names_its_reviewer_and_its_time_together(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();

        $this->assertRejectedBy(
            self::TABLE,
            'order_ratings_reviewed_check',
            $this->row(['reviewed_at' => now()]),
            'BR-RATE-003: a review names who.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_ratings_reviewed_check',
            $this->row(['reviewed_by_user_id' => $operator->id]),
            'BR-RATE-003: a review says when.'
        );
    }
}
