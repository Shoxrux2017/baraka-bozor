<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\LegalDocumentKind;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Auth\LoginCodeCheck;
use App\Modules\Auth\LoginCodePolicy;
use App\Modules\Auth\LoginCodeRefused;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\Models\StaffLoginStep;
use App\Modules\Auth\StaffAccounts;
use App\Modules\Legal\LegalDocuments;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * `POST /auth/customer/code/verify` — docs/09 Section 7.
 *
 * Checks the code against the newest open challenge for the phone, then
 * resolves the active Customer account or creates one. The order is
 * load-bearing: an invalid, expired or exhausted code fails with its own code
 * whatever the account's status, so `account_blocked` is reachable only by
 * whoever holds the code and never becomes an account-status oracle.
 *
 * Never issues a STAFF session: a phone held by a Staff account simply gets a
 * Customer account beside it (`BR-ROLE-010`). For a Shopper or Courier it may
 * hand out a single-use staff step, redeemed with the password at
 * `POST /auth/staff/step` (`DL-77`).
 */
final class VerifyCustomerLoginCode
{
    public function __construct(
        private readonly LoginCodeCheck $check,
        private readonly LegalDocuments $documents,
    ) {}

    public function __invoke(string $phone, #[\SensitiveParameter] string $code): VerifiedLogin
    {
        try {
            $this->check->consume($phone, $code, LoginChallenge::PURPOSE_CUSTOMER_LOGIN);
        } catch (LoginCodeRefused $refusal) {
            throw $refusal->apiCode === 'code_locked'
                ? ApiException::tooManyRequests('code_locked', $refusal->retryAfterSeconds ?? LoginCodePolicy::LOCK_SECONDS)
                : ApiException::unauthenticated($refusal->apiCode);
        }

        // The code is consumed and committed above, so a blocked account's
        // refusal below cannot give the code a second use.
        return DB::transaction(fn (): VerifiedLogin => $this->openSession($phone));
    }

    private function openSession(string $phone): VerifiedLogin
    {
        $customer = $this->resolveCustomer($phone);

        $customer->last_login_at = now();

        // Consent names an edition, so it is recorded only when one is published.
        if ($this->anyDocumentPublished()) {
            $customer->terms_accepted_at = now();
        }

        $customer->save();

        $session = new IssuedSession($customer->createToken('customer')->plainTextToken, $customer);

        return $this->withStaffStep($session, $phone);
    }

    private function anyDocumentPublished(): bool
    {
        foreach ([LegalDocumentKind::Terms, LegalDocumentKind::Privacy] as $kind) {
            foreach (LegalDocuments::LANGUAGES as $language) {
                if ($this->documents->published($kind, $language) !== null) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Hands out the staff step when the phone also holds a Shopper or Courier
     * account, active or blocked (the block is answered at the password), and
     * closes any earlier open step of that account.
     */
    private function withStaffStep(IssuedSession $session, string $phone): VerifiedLogin
    {
        // The same account the password login resolves: a Shopper or Courier
        // that is not the phone's current staff account gets no step.
        $staff = StaffAccounts::currentFor($phone);

        if ($staff === null || ! in_array($staff->role, [Role::Shopper, Role::Courier], true)) {
            return new VerifiedLogin($session, null, null);
        }

        StaffLoginStep::query()
            ->where('staff_user_id', $staff->id)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);

        $token = Str::random(64);
        $expiresAt = CarbonImmutable::now()->addSeconds(StaffLoginStep::TTL_SECONDS);

        StaffLoginStep::query()->forceCreate([
            'staff_user_id' => $staff->id,
            'token_hash' => hash('sha256', $token),
            'expires_at' => $expiresAt,
        ]);

        return new VerifiedLogin($session, $token, $expiresAt);
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
