<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Models\User;

/**
 * The outcome of a successful staff login: the plain-text token, which exists
 * only in this response, and the account it belongs to.
 */
final class AuthenticatedStaff
{
    public function __construct(
        public readonly string $token,
        public readonly User $user,
    ) {}
}
