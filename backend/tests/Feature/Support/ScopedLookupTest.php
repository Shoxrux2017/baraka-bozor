<?php

declare(strict_types=1);

namespace Tests\Feature\Support;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use LogicException;
use Mockery;
use Mockery\MockInterface;
use Tests\TestCase;

final class ScopedLookupTest extends TestCase
{
    use RefreshDatabase;

    public function test_lock_or_not_found_returns_the_locked_row_inside_a_transaction(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();

        $found = DB::transaction(fn (): User => ScopedLookup::lockOrNotFound(User::query()->whereKey($operator->id)));

        $this->assertSame($operator->id, $found->id);
    }

    public function test_lock_or_not_found_answers_the_scope_safe_not_found_inside_a_transaction(): void
    {
        $this->expectException(ApiException::class);
        $this->expectExceptionMessage('404 resource_not_found');

        DB::transaction(fn () => ScopedLookup::lockOrNotFound(User::query()->where('phone', '+998900000000')));
    }

    public function test_a_lock_outside_a_transaction_is_refused(): void
    {
        // The test suite itself runs inside a transaction, so the guard is
        // exercised against a connection that reports none.
        /** @var ConnectionInterface&MockInterface $connection */
        $connection = Mockery::mock(ConnectionInterface::class);
        $connection->shouldReceive('transactionLevel')->once()->andReturn(0);

        $this->expectException(LogicException::class);
        $this->expectExceptionMessage('inside a database transaction');

        ScopedLookup::assertInsideTransaction($connection);
    }
}
