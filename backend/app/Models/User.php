<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;

/**
 * Framework placeholder so the `users` auth provider resolves.
 *
 * The real BarakaBozor identity model, its UUID key, its six roles, its
 * account status and its first-login gate are created by S01-BE-002 together
 * with the `users` table. Nothing business-specific belongs here yet, and no
 * `users` table exists at this Stage.
 */
class User extends Authenticatable
{
    //
}
