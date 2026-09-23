<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

/**
 * An account, in either of the two families the platform has.
 *
 * A Customer signs in by OTP and holds no password; Staff — the other five roles
 * of `BR-ROLE-001` — sign in by phone and password and must hold one. The
 * difference is structural, not a matter of policy, and the database enforces it
 * through `users_password_by_family_check`. Nothing here may weaken that.
 *
 * `$fillable` is deliberately short. `AGENTS.md` Section 6 makes the backend
 * authoritative for the role and for the active/blocked state, so `role`,
 * `status`, `must_change_password` and `created_by_user_id` are left out: a
 * controller that ever passes request input straight into this model must not be
 * able to hand out a role with it. Code that legitimately sets them assigns them
 * explicitly, and says so at the point it does.
 *
 * @property string $id
 * @property Role $role
 * @property string $phone
 * @property string|null $full_name
 * @property string|null $password
 * @property UserStatus $status
 * @property bool $must_change_password
 * @property Carbon|null $password_changed_at
 * @property Carbon|null $last_login_at
 * @property Carbon|null $blocked_at
 * @property string|null $created_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class User extends Authenticatable
{
    use HasApiTokens;

    /** @use HasFactory<UserFactory> */
    use HasFactory;
    use HasUuids;

    /**
     * Ordinary input a request may carry. See the class docblock for what is
     * missing from this list and why.
     *
     * @var list<string>
     */
    protected $fillable = [
        'phone',
        'full_name',
        'password',
    ];

    /**
     * @var list<string>
     */
    protected $hidden = [
        'password',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'role' => Role::class,
            'status' => UserStatus::class,
            'must_change_password' => 'boolean',

            // Hashes on assignment, and leaves an already-hashed value alone, so
            // saving an unrelated field cannot re-hash the stored hash. A null
            // stays null, which is what a Customer row requires.
            'password' => 'hashed',

            'password_changed_at' => 'datetime',
            'last_login_at' => 'datetime',
            'blocked_at' => 'datetime',
        ];
    }

    /**
     * Whether this account belongs to the Staff family.
     */
    public function isStaff(): bool
    {
        return $this->role->isStaff();
    }
}
