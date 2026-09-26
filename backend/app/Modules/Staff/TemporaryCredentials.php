<?php

declare(strict_types=1);

namespace App\Modules\Staff;

use App\Models\User;

/**
 * A staff account together with the temporary password just set on it, for
 * the one response allowed to carry the password.
 */
final readonly class TemporaryCredentials
{
    public function __construct(
        public User $staff,
        #[\SensitiveParameter] public string $password,
    ) {}
}
