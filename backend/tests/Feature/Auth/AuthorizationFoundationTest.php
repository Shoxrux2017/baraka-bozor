<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Support\Scope\ScopedLookup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The six authorization layers of docs/07 Section 9 on probe routes that
 * exist only in this test: every role enters only what its surface admits,
 * a foreign record answers a scope-safe 404, and the refusals carry the
 * codes docs/09 Sections 51 and 52 fix.
 */
final class AuthorizationFoundationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['api', 'protected'])->prefix('api/v1/testing')->group(function (): void {
            Route::get('customer-only', fn () => response()->json(['data' => ['surface' => 'customer']]))
                ->middleware(RequireRole::of(Role::Customer));

            Route::get('operations', fn () => response()->json(['data' => ['surface' => 'operations']]))
                ->middleware(RequireRole::of(Role::Operator, Role::Admin));

            Route::get('admin-only', fn () => response()->json(['data' => ['surface' => 'admin']]))
                ->middleware(RequireRole::of(Role::Admin));

            // A record lookup scoped to the actor: only the actor's own row is
            // in scope, so any other id — existing or not — is out of it.
            Route::get('scoped/{id}', function (Request $request, string $id) {
                $actor = $request->user();
                $found = ScopedLookup::firstOrNotFound(User::query()->whereKey($id)->whereKey($actor?->getKey()));

                return response()->json(['data' => ['id' => $found->id]]);
            })->middleware(RequireRole::of(Role::Customer));
        });
    }

    /**
     * @return array<string, array{Role, string, int}>
     */
    public static function surfaceCases(): array
    {
        return [
            'customer on the customer surface' => [Role::Customer, 'customer-only', 200],
            'customer on operations' => [Role::Customer, 'operations', 403],
            'customer on admin' => [Role::Customer, 'admin-only', 403],
            'shopper on the customer surface' => [Role::Shopper, 'customer-only', 403],
            'shopper on operations' => [Role::Shopper, 'operations', 403],
            'courier on operations' => [Role::Courier, 'operations', 403],
            'operator on operations' => [Role::Operator, 'operations', 200],
            'operator on admin' => [Role::Operator, 'admin-only', 403],
            'admin on operations' => [Role::Admin, 'operations', 200],
            'admin on admin' => [Role::Admin, 'admin-only', 200],
            'admin on the customer surface' => [Role::Admin, 'customer-only', 403],
            'manager on operations' => [Role::Manager, 'operations', 403],
            'manager on admin' => [Role::Manager, 'admin-only', 403],
        ];
    }

    #[DataProvider('surfaceCases')]
    public function test_each_role_enters_only_what_its_surface_admits(Role $role, string $probe, int $status): void
    {
        $response = $this->as(User::factory()->role($role)->create())->getJson("/api/v1/testing/{$probe}");

        $response->assertStatus($status);

        if ($status === 403) {
            $response->assertJsonPath('code', 'forbidden');
        }
    }

    public function test_without_a_token_every_probe_is_authentication_required(): void
    {
        foreach (['customer-only', 'operations', 'admin-only', 'scoped/'.Str::uuid()] as $probe) {
            $this->getJson("/api/v1/testing/{$probe}")
                ->assertStatus(401)
                ->assertJsonPath('code', 'authentication_required');
        }
    }

    public function test_a_blocked_account_is_refused_before_its_role_is_considered(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $token = $admin->createToken('test')->plainTextToken;
        $admin->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();

        $this->withToken($token)->getJson('/api/v1/testing/admin-only')
            ->assertStatus(401)
            ->assertJsonPath('code', 'account_blocked');
    }

    public function test_the_first_login_gate_is_checked_before_the_role(): void
    {
        $this->as(User::factory()->role(Role::Admin)->mustChangePassword()->create())
            ->getJson('/api/v1/testing/admin-only')
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');
    }

    public function test_a_record_in_scope_is_found(): void
    {
        $customer = User::factory()->customer()->create();

        $this->as($customer)->getJson("/api/v1/testing/scoped/{$customer->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $customer->id);
    }

    public function test_a_foreign_record_and_a_missing_record_are_the_same_scope_safe_not_found(): void
    {
        $customer = User::factory()->customer()->create();
        $other = User::factory()->customer()->create();

        $foreign = $this->as($customer)->getJson("/api/v1/testing/scoped/{$other->id}");
        $missing = $this->as($customer)->getJson('/api/v1/testing/scoped/'.Str::uuid());

        foreach ([$foreign, $missing] as $response) {
            $response->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        }

        // Byte-identical apart from the request id: a valid UUID that exists
        // reveals nothing a random one would not.
        $this->assertSame(
            $this->withoutRequestId($foreign),
            $this->withoutRequestId($missing)
        );
    }

    public function test_the_role_middleware_refuses_to_be_mounted_without_a_role(): void
    {
        Route::middleware(['api', 'protected', 'role'])->get('api/v1/testing/roleless', fn () => 'never');

        config(['app.debug' => false]);

        // A misconfigured route is a server failure, never an open door.
        $this->as(User::factory()->role(Role::Admin)->create())
            ->getJson('/api/v1/testing/roleless')
            ->assertStatus(500)
            ->assertJsonPath('code', 'server_error');
    }

    private function as(User $user): static
    {
        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    /**
     * @return array<string, mixed>
     */
    private function withoutRequestId(TestResponse $response): array
    {
        $body = $response->json();
        $this->assertIsArray($body);
        unset($body['request_id']);

        return $body;
    }
}
