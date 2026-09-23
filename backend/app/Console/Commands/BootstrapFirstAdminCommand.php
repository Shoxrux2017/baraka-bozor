<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Console\Command;
use Throwable;

/**
 * Creates the platform's first Admin — `BR-ROLE-009`, the controlled one-time
 * bootstrap that exists because no public API may ever mint an Admin.
 *
 * The password is read from a hidden prompt and from nowhere else. It is not an
 * option and not an argument, so it never reaches `argv`, where a process list
 * and the shell history would both keep it, and it is never printed or logged.
 * `AGENTS.md` Section 6 forbids exposing a password with no environment
 * qualifier, and a local shell history is an exposure.
 *
 * The prompt asks twice because it shows nothing back, and because this one
 * account cannot be reset by anybody: a typo would lock the platform's first
 * Admin out permanently.
 *
 * The write is guarded for the same reason. An unhandled `QueryException` from
 * `save()` carries the whole statement, and the statement carries the bcrypt
 * hash of the password just chosen — Laravel would print it and write it to
 * `storage/logs/laravel.log`, a plaintext file with looser access control than
 * the database and one that is routinely shipped off-host. So nothing derived
 * from the credential leaves this command on any path, and `AGENTS.md` Section 9
 * keeps the SQL and the trace out of the operator's terminal too.
 *
 * No password policy is imposed here beyond refusing an empty one. None is
 * locked in `docs/01`–`09`, and inventing a rule the change-password endpoint
 * would then have to match is a decision reserved to the Project Owner;
 * `S01-BE-003` owns it.
 */
final class BootstrapFirstAdminCommand extends Command
{
    /**
     * No `--password` option, deliberately. See the class docblock.
     *
     * @var string
     */
    protected $signature = 'bootstrap:first-admin
                            {phone : The Admin phone in E.164, +998 and nine digits}
                            {--name= : Full name to record on the account}';

    protected $description = 'Create the first Admin account (BR-ROLE-009). Runs once, before any Admin exists.';

    /** The same shape `users_phone_format_check` enforces. */
    private const PHONE_PATTERN = '/^\+998[0-9]{9}$/';

    public function handle(): int
    {
        // Checked before the prompt, not after. A prompt that appears and is then
        // discarded invites the operator to type a real password into a run that
        // will not use it.
        if (User::query()->where('role', Role::Admin->value)->exists()) {
            $this->error(
                'An Admin account already exists, so the one-time bootstrap is closed. '
                .'Further Admins are created by an existing Admin, never by this command.'
            );

            return self::FAILURE;
        }

        $phone = (string) $this->argument('phone');

        if (preg_match(self::PHONE_PATTERN, $phone) !== 1) {
            $this->error("\"{$phone}\" is not a valid phone. Expected +998 followed by nine digits.");

            return self::FAILURE;
        }

        // Checked before the prompt as well, so the likeliest failure of the
        // write is met with an explanation rather than with a discarded password
        // — and never reaches a statement carrying the hash.
        if (User::query()->where('phone', $phone)->where('status', UserStatus::Active->value)->exists()) {
            $this->error("An active account already exists for {$phone}, so it cannot take another one.");

            return self::FAILURE;
        }

        // `false` disables Symfony's fallback to visible input when hidden input
        // is unavailable. Echoing the password would be worse than refusing.
        $password = (string) $this->secret('Password', false);

        if ($password === '') {
            $this->error('The password was empty; no account was created.');

            return self::FAILURE;
        }

        if ($password !== (string) $this->secret('Confirm password', false)) {
            $this->error('The two passwords did not match; no account was created.');

            return self::FAILURE;
        }

        $admin = new User;

        // Assigned rather than mass-assigned: `role` and `status` are kept out of
        // the model's `$fillable` precisely so that nothing sets them from input,
        // and this is one of the few places entitled to decide them.
        $admin->forceFill([
            'role' => Role::Admin,
            'phone' => $phone,
            'full_name' => $this->option('name'),

            // The model's `hashed` cast turns this into a hash on assignment, so
            // the plaintext never reaches the database.
            'password' => $password,
            'status' => UserStatus::Active,

            // BR-ROLE-005 sets the gate for Staff who receive a server-generated
            // temporary password they did not choose. This password was chosen by
            // the person running the command, so a forced change would remedy
            // nothing.
            'must_change_password' => false,
            'password_changed_at' => now(),
            'created_by_user_id' => null,
        ]);

        try {
            $admin->save();
        } catch (Throwable) {
            // Deliberately nothing from the exception: not its message, not the
            // statement, not the trace. The statement holds the hash, and the
            // operator is standing at the terminal and can simply retry.
            $this->error(
                'The account could not be created, and nothing was written. Check that the '
                .'database is reachable, that the name is at most 160 characters, and that no '
                .'active account already holds this phone.'
            );

            return self::FAILURE;
        }

        $this->info("Admin created for {$phone}.");

        return self::SUCCESS;
    }
}
