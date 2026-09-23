<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Console\Command\Command;
use Tests\TestCase;

/**
 * `BR-ROLE-009`: the first Admin is created through a controlled one-time
 * backend CLI, never a public API. This command is that CLI, and it is the only
 * way an account exists before any account exists.
 *
 * Two properties carry the weight. It must be one-time — an operator who can run
 * it twice can mint themselves an Admin on a live system. And the password must
 * not leak: `AGENTS.md` Section 6 forbids exposing or logging one, with no
 * environment qualifier, so it may not appear in the output, in a log, or in
 * `argv`, where a process list and the shell history would both keep it.
 */
final class BootstrapFirstAdminCommandTest extends TestCase
{
    use RefreshDatabase;

    private const COMMAND = 'bootstrap:first-admin';

    private const PHONE = '+998901234567';

    private const PASSWORD = 'correct horse battery staple';

    public function test_it_creates_the_first_admin(): void
    {
        $this->artisan(self::COMMAND, ['phone' => self::PHONE, '--name' => 'Bootstrap Admin'])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', self::PASSWORD)
            ->assertExitCode(Command::SUCCESS);

        $admin = User::query()->sole();

        $this->assertSame(Role::Admin, $admin->role);
        $this->assertSame(UserStatus::Active, $admin->status);
        $this->assertSame(self::PHONE, $admin->phone);
        $this->assertSame('Bootstrap Admin', $admin->full_name);

        // BR-ROLE-005 sets the gate for Staff who receive a server-generated
        // temporary password they did not choose. The Project Owner chooses this
        // one, so a forced change would remedy nothing.
        $this->assertFalse($admin->must_change_password);

        $this->assertNull($admin->created_by_user_id, 'Nobody created the first Admin.');
        $this->assertTrue(Hash::check(self::PASSWORD, (string) $admin->password));
    }

    public function test_it_refuses_when_an_admin_already_exists(): void
    {
        $existing = User::factory()->role(Role::Admin)->create();

        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->assertExitCode(Command::FAILURE);

        $this->assertSame(
            1,
            User::query()->count(),
            'The command created an account despite refusing. An operator who can run it twice '
            .'on a live system can mint themselves an Admin.'
        );

        $this->assertTrue(User::query()->whereKey($existing->id)->exists());
    }

    public function test_it_refuses_before_asking_for_a_password_when_an_admin_exists(): void
    {
        // The order matters: a prompt that appears and is then discarded invites
        // the operator to type a real password into a session that will not use
        // it. `expectsQuestion` is deliberately not set here, so the test fails
        // if the command asks.
        User::factory()->role(Role::Admin)->create();

        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->assertExitCode(Command::FAILURE);
    }

    public function test_a_blocked_admin_still_counts_as_an_existing_admin(): void
    {
        // Otherwise blocking the only Admin would reopen the one-time path.
        // BR-ROLE-008 already forbids blocking the last active Admin, so this
        // closes the remaining way round it rather than creating a lockout.
        User::factory()->role(Role::Admin)->blocked()->create();

        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->assertExitCode(Command::FAILURE);

        $this->assertSame(1, User::query()->count());
    }

    public function test_a_staff_account_that_is_not_an_admin_does_not_block_the_bootstrap(): void
    {
        User::factory()->role(Role::Operator)->create();

        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', self::PASSWORD)
            ->assertExitCode(Command::SUCCESS);

        $this->assertSame(1, User::query()->where('role', Role::Admin->value)->count());
    }

    public function test_the_password_cannot_be_passed_on_the_command_line(): void
    {
        // The whole reason for the prompt. An option or argument would put the
        // password into argv, where the process list and the shell history both
        // keep it, and no amount of care at the call site would take it back.
        $definition = $this->app->make(Kernel::class)
            ->all()[self::COMMAND]
            ->getDefinition();

        foreach (array_keys($definition->getOptions()) as $option) {
            $this->assertStringNotContainsStringIgnoringCase('password', $option);
        }

        foreach (array_keys($definition->getArguments()) as $argument) {
            $this->assertStringNotContainsStringIgnoringCase('password', $argument);
        }
    }

    public function test_it_never_prints_the_password(): void
    {
        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', self::PASSWORD)
            ->doesntExpectOutputToContain(self::PASSWORD)
            ->assertExitCode(Command::SUCCESS);
    }

    public function test_it_never_logs_the_password(): void
    {
        $log = Log::spy();

        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', self::PASSWORD)
            ->assertExitCode(Command::SUCCESS);

        // The command writes no log line at all, which is the only guarantee that
        // survives a later edit: a rule of the form "log, but not the password"
        // is one careless interpolation away from breaking.
        foreach (['log', 'info', 'debug', 'notice', 'warning', 'error'] as $level) {
            $log->shouldNotHaveReceived($level);
        }
    }

    public function test_it_refuses_when_the_confirmation_does_not_match(): void
    {
        // A hidden prompt shows nothing back, and this account cannot be reset by
        // anyone: a typo would lock the platform's first Admin out permanently.
        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', 'something else')
            ->assertExitCode(Command::FAILURE);

        $this->assertSame(0, User::query()->count());
    }

    public function test_it_refuses_an_empty_password(): void
    {
        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', '')
            ->assertExitCode(Command::FAILURE);

        $this->assertSame(0, User::query()->count());
    }

    public function test_it_rejects_a_phone_outside_the_locked_format(): void
    {
        // Rejected here rather than left to the database, so the operator sees
        // what is wrong instead of a constraint violation — and before being
        // asked for a password the command will throw away.
        $this->artisan(self::COMMAND, ['phone' => '998901234567'])
            ->assertExitCode(Command::FAILURE);

        $this->assertSame(0, User::query()->count());
    }

    public function test_the_created_admin_holds_the_instant_it_chose_its_password(): void
    {
        $this->artisan(self::COMMAND, ['phone' => self::PHONE])
            ->expectsQuestion('Password', self::PASSWORD)
            ->expectsQuestion('Confirm password', self::PASSWORD)
            ->assertExitCode(Command::SUCCESS);

        $this->assertNotNull(
            User::query()->sole()->password_changed_at,
            'The password was chosen now, and password_changed_at is what a later expiry policy '
            .'would measure from.'
        );
    }
}
