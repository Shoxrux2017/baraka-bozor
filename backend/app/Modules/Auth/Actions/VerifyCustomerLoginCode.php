<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Auth\LoginCodePolicy;
use App\Modules\Auth\Models\LoginChallenge;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * `POST /auth/customer/code/verify` — docs/09 Section 7.
 *
 * Checks the code against the newest open challenge for the phone, then
 * resolves the active Customer account or creates one. The order is
 * load-bearing: an invalid, expired or exhausted code fails with its own code
 * whatever the account's status, so `account_blocked` is reachable only by
 * whoever holds the code and never becomes an account-status oracle.
 *
 * Never resolves a Staff account: a phone held by an active Staff account
 * simply gets a Customer account beside it (`BR-ROLE-010`).
 */
final class VerifyCustomerLoginCode
{
    public function __invoke(string $phone, #[\SensitiveParameter] string $code): IssuedSession
    {
        /** @var ApiException|null $refusal */
        $refusal = null;

        // A refusal is thrown only after the transaction has committed: the
        // failed-attempt count and the consumption of the code must persist,
        // and an exception escaping the closure would roll them back.
        $session = DB::transaction(function () use ($phone, $code, &$refusal): ?IssuedSession {
            try {
                return $this->verify($phone, $code);
            } catch (ApiException $exception) {
                $refusal = $exception;

                return null;
            }
        });

        if ($refusal !== null) {
            throw $refusal;
        }

        // The closure returns null only alongside a refusal.
        assert($session instanceof IssuedSession);

        return $session;
    }

    private function verify(string $phone, #[\SensitiveParameter] string $code): IssuedSession
    {
        $challenge = LoginChallenge::query()
            ->openFor($phone)
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->first();

        if ($challenge === null) {
            throw ApiException::unauthenticated('code_invalid');
        }

        if ($challenge->isExpired()) {
            throw ApiException::unauthenticated('code_expired');
        }

        if ($challenge->failed_attempts >= LoginCodePolicy::MAX_FAILED_ATTEMPTS) {
            throw ApiException::unauthenticated('code_attempts_exhausted');
        }

        if (! Hash::check($code, $challenge->code_hash)) {
            $challenge->forceFill(['failed_attempts' => $challenge->failed_attempts + 1])->save();

            throw ApiException::unauthenticated('code_invalid');
        }

        // Consumed before the account is looked at, so a valid code opens
        // nothing twice — not even for a blocked account.
        $challenge->forceFill(['consumed_at' => now()])->save();

        $customer = $this->resolveCustomer($phone);

        $customer->forceFill(['last_login_at' => now()])->save();

        return new IssuedSession($customer->createToken('customer')->plainTextToken, $customer);
    }

    /**
     * The active Customer account for the phone, created when none is active.
     * A blocked one is never resolved and never bypassed.
     */
    private function resolveCustomer(string $phone): User
    {
        $customers = User::query()
            ->where('phone', $phone)
            ->where('role', Role::Customer->value)
            ->get();

        $active = $customers->first(fn (User $user): bool => $user->status === UserStatus::Active);

        if ($active !== null) {
            return $active;
        }

        if ($customers->isNotEmpty()) {
            // Only blocked Customer accounts exist for the phone: creating a
            // fresh one would let a block be escaped with one code.
            throw ApiException::unauthenticated('account_blocked');
        }

        $customer = new User;

        // Assigned, not mass-assigned: `role` and `status` stay out of
        // `$fillable` so that no request input can ever set them.
        $customer->forceFill([
            'role' => Role::Customer,
            'phone' => $phone,
            'full_name' => null,
            'password' => null,
            'status' => UserStatus::Active,
            'must_change_password' => false,
            'preferred_language' => 'uz',
            'created_by_user_id' => null,
        ])->save();

        return $customer;
    }
}
