<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Identity\AssertsDatabaseRejections;
use Tests\Feature\Identity\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `push_devices`, as `docs/08-database.md` Section 25 names it.
 */
final class PushDevicesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'push_devices';

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'user_id' => ['uuid', false],
            'platform' => ['character varying', false],
            'push_token' => ['character varying', false],
            'last_seen_at' => ['timestamp with time zone', true],
            'revoked_at' => ['timestamp with time zone', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'user_id' => User::factory()->customer()->create()->id,
            'platform' => 'android',
            'push_token' => 'fcm-'.Str::random(40),
            'last_seen_at' => now(),
            'revoked_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types(): void
    {
        $actual = $this->columnsOf(self::TABLE);
        $expected = $this->expectedColumns();

        $names = array_keys($actual);
        $expectedNames = array_keys($expected);
        sort($names);
        sort($expectedNames);
        $this->assertSame($expectedNames, $names);

        foreach ($expected as $column => [$type, $nullable]) {
            $this->assertSame($type, $actual[$column]->data_type, self::TABLE.".{$column} type");
            $this->assertSame($nullable ? 'YES' : 'NO', $actual[$column]->is_nullable, self::TABLE.".{$column} nullability");
        }
    }

    public function test_one_token_registers_once_per_account_but_once_for_each_account(): void
    {
        // Interview 7.0: a phone holding a Customer and a Staff account
        // registers its token for both, so the pair is the key, not the token.
        $token = 'fcm-'.Str::random(40);
        $first = User::factory()->customer()->create();
        $second = User::factory()->create();

        DB::table(self::TABLE)->insert($this->row(['user_id' => $first->id, 'push_token' => $token]));
        DB::table(self::TABLE)->insert($this->row(['user_id' => $second->id, 'push_token' => $token]));

        $this->assertSame(2, DB::table(self::TABLE)->where('push_token', $token)->count());

        $this->assertRejectedBy(
            self::TABLE,
            'push_devices_push_token_user_id_unique',
            $this->row(['user_id' => $first->id, 'push_token' => $token]),
            'A second registration of the same token by the same account is an update, not a row.'
        );
    }

    public function test_a_platform_outside_the_three_and_a_blank_token_are_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'push_devices_platform_check',
            $this->row(['platform' => 'huawei']),
            '08 Section 25 names android, ios and web.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'push_devices_push_token_not_blank_check',
            $this->row(['push_token' => '  ']),
            'A blank token can deliver nothing.'
        );
    }

    public function test_live_devices_are_indexed_per_account(): void
    {
        $indexes = $this->indexesOn(self::TABLE);

        $this->assertArrayHasKey('push_devices_user_live_index', $indexes);
        $this->assertStringContainsString('WHERE (revoked_at IS NULL)', $indexes['push_devices_user_live_index']);
    }
}
