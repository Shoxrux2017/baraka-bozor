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
 * Layers 1 to 4 of docs/07 Section 9 on probe routes that exist only in this
 * test: every role against every surface, the refusal order, and a foreign
 * record answering the same scope-safe 404 as a missing one. Layers 5 and 6
 * (lifecycle condition, state under lock) live in the actions that own them.
 */
final class AuthorizationFoundationTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, list<Role>> probe => the roles it admits */
    private const ADMITTED = [
        'customer-only' => [Role::Customer],
        'operations' => [Role::Operator, Role::Admin],
        'admin-only' => [Role::Admin],
    ];

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['api', 'protected'])->prefix('api/v1/testing')->group(function (): void {
            foreach (self::ADMITTED as $probe => $roles) {
                Route::get($probe, fn () => response()->json(['data' => ['surface' => $probe]]))
                    ->middleware(RequireRole::of(...$roles));
            }

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
     * Every role against every probe, generated so a role or a probe cannot
     * be left out by hand.
     *
     * @return array<string, array{Role, string, bool}>
     */
    public static function surfaceCases(): array
    {
        $cases = [];

        foreach (Role::cases() as $role) {
            foreach (self::ADMITTED as $probe => $admitted) {
                $cases["{$role->value} on {$probe}"] = [$role, $probe, in_array($role, $admitted, true)];
            }
        }

        return $cases;
    }

    #[DataProvider('surfaceCases')]
    public function test_each_role_enters_only_what_its_surface_admits(Role $role, string $probe, bool $admitted): void
    {
        $response = $this->signedInAs(User::factory()->role($role)->create())->getJson("/api/v1/testing/{$probe}");

        if ($admitted) {
            $response->assertOk()->assertJsonPath('data.surface', $probe);
        } else {
            $response->assertStatus(403)->assertJsonPath('code', 'forbidden');
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
        // A Shopper is not admitted to admin-only, so a role check that ran
        // first would answer 403 forbidden; the blocked check must win.
        $shopper = User::factory()->role(Role::Shopper)->create();
        $token = $shopper->createToken('test')->plainTextToken;
        $shopper->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();

        $this->withToken($token)->getJson('/api/v1/testing/admin-only')
            ->assertStatus(401)
            ->assertJsonPath('code', 'account_blocked');
    }

    public function test_the_first_login_gate_is_checked_before_the_role(): void
    {
        // Same idea: a gated Shopper on admin-only gets the gate, not 403.
        $this->signedInAs(User::factory()->role(Role::Shopper)->mustChangePassword()->create())
            ->getJson('/api/v1/testing/admin-only')
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');
    }

    public function test_a_record_in_scope_is_found(): void
    {
        $customer = User::factory()->customer()->create();

        $this->signedInAs($customer)->getJson("/api/v1/testing/scoped/{$customer->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $customer->id);
    }

    public function test_a_foreign_record_a_missing_record_and_a_malformed_id_are_the_same_not_found(): void
    {
        $customer = User::factory()->customer()->create();
        $other = User::factory()->customer()->create();

        $foreign = $this->signedInAs($customer)->getJson("/api/v1/testing/scoped/{$other->id}");
        $missing = $this->signedInAs($customer)->getJson('/api/v1/testing/scoped/'.Str::uuid());
        $malformed = $this->signedInAs($customer)->getJson('/api/v1/testing/scoped/not-a-uuid');

        foreach ([$foreign, $missing, $malformed] as $response) {
            $response->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        }

        // The same bytes apart from the request id: a valid UUID that exists
        // reveals nothing a random one, or a malformed one, would not.
        $this->assertSame($this->bodyWithoutRequestId($foreign), $this->bodyWithoutRequestId($missing));
        $this->assertSame($this->bodyWithoutRequestId($foreign), $this->bodyWithoutRequestId($malformed));
    }

    public function test_a_role_check_mounted_without_a_role_is_a_server_failure_not_an_open_door(): void
    {
        Route::middleware(['api', 'protected', 'role'])->get('api/v1/testing/roleless', fn () => 'never');

        $this->signedInAs(User::factory()->role(Role::Admin)->create())
            ->getJson('/api/v1/testing/roleless')
            ->assertStatus(500)
            ->assertJsonPath('code', 'server_error');
    }

    private function signedInAs(User $user): static
    {
        return $this->withToken($user->createToken('test')->plainTextToken);
    }

    private function bodyWithoutRequestId(TestResponse $response): string
    {
        $body = (string) $response->getContent();

        $this->assertMatchesRegularExpression('/"request_id":"req_[0-9a-z]{26}"/', $body);

        return (string) preg_replace('/"request_id":"req_[0-9a-z]{26}"/', '"request_id":"-"', $body);
    }
}
