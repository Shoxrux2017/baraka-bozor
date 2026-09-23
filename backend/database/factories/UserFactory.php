<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds accounts the database will actually accept.
 *
 * Delivered by the schema task rather than by the tasks that use it, because
 * `backend/database/factories/**` belongs to the `wave-owner` track and the
 * `auth-backend` track would otherwise have to edit a path it does not own to
 * test anything involving a user.
 *
 * Every state keeps the two family rules intact — a Customer holds no password
 * and no first-login gate, Staff hold a password — so a caller that picks a role
 * does not also have to remember what that role implies. Getting it wrong would
 * not produce a subtly odd fixture; it would fail on a `CHECK`, in a test about
 * something else entirely.
 *
 * @extends Factory<User>
 */
final class UserFactory extends Factory
{
    protected $model = User::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            // Operator, not Admin. This factory is a public contract for the
            // auth-backend track, and a default that grants the most privileged
            // role would let an under-specified test pass for the wrong reason —
            // besides silently closing the one-time bootstrap in any test that
            // creates a default user.
            'role' => Role::Operator,
            'phone' => $this->phone(),
            'full_name' => fake()->name(),

            // The model's `hashed` cast turns this into a hash on assignment, so
            // no plaintext reaches the database even in a test fixture.
            'password' => 'password',
            'status' => UserStatus::Active,
            'must_change_password' => false,
            'password_changed_at' => null,
            'last_login_at' => null,
            'blocked_at' => null,
            'created_by_user_id' => null,
        ];
    }

    /**
     * An account in the given role, with whatever that role implies.
     */
    public function role(Role $role): self
    {
        return $this->state(fn (): array => $role->isStaff()
            ? ['role' => $role, 'password' => 'password']
            : ['role' => $role, 'password' => null, 'must_change_password' => false]);
    }

    public function customer(): self
    {
        return $this->role(Role::Customer);
    }

    /**
     * A blocked account, with the instant `users_blocked_at_check` requires.
     */
    public function blocked(): self
    {
        return $this->state(fn (): array => [
            'status' => UserStatus::Blocked,
            'blocked_at' => now(),
        ]);
    }

    /**
     * A Staff account that must change its password before it can do anything
     * else — `BR-ROLE-005`, the state a server-generated temporary password
     * leaves an account in.
     *
     * Combining this with `customer()` is a contradiction, and the database says
     * so: `users_customer_no_password_gate_check` rejects it. The state does not
     * quietly rewrite the role to paper over the mistake.
     */
    public function mustChangePassword(): self
    {
        return $this->state(fn (): array => ['must_change_password' => true]);
    }

    /**
     * Build the model with `forceFill`.
     *
     * `User` deliberately keeps `role`, `status`, `must_change_password` and
     * `created_by_user_id` out of `$fillable`, because `AGENTS.md` Section 6
     * makes the server authoritative over them. A factory is not request input,
     * so it sets them directly rather than the model relaxing a guard that
     * exists for the request path.
     *
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): User
    {
        return (new User)->forceFill($attributes);
    }

    /**
     * A distinct E.164 Uzbek number per account.
     *
     * Distinct because `users_phone_active_staff_unique` allows one active Staff
     * account per phone, so a repeated number would fail the moment a test needed
     * two accounts.
     */
    private function phone(): string
    {
        return '+998'.fake()->unique()->numerify('#########');
    }
}
