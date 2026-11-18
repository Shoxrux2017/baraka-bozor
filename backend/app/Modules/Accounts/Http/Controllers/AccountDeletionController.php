<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Http\Controllers;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\User;
use App\Modules\Accounts\Actions\EraseCustomer;
use App\Modules\Accounts\Http\Requests\DeleteAccountRequest;
use App\Modules\Accounts\UnfinishedOrders;
use App\Modules\Auth\Actions\RequestCustomerLoginCode;
use App\Modules\Auth\LoginCodeCheck;
use App\Modules\Auth\LoginCodePolicy;
use App\Modules\Auth\LoginCodeRefused;
use App\Modules\Auth\Models\LoginChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

/**
 * A Customer deletes their own account with a deletion code
 * (`docs/09` Sections 64 and 65, `BR-ROLE-013`).
 *
 * The routes are authenticated, so a refused code answers `422`, never `401`:
 * the client treats a `401` as a lost session and signs the person out.
 */
final class AccountDeletionController extends Controller
{
    public function requestCode(EmptyBodyRequest $request, RequestCustomerLoginCode $requestCode): JsonResponse
    {
        $customer = $this->customer($request);
        $this->refuseWhileUnfinished($customer);

        $issued = $requestCode($this->phone($customer), (string) $request->ip(), LoginChallenge::PURPOSE_ACCOUNT_DELETION);

        return new JsonResponse([
            'data' => [
                'channel' => $issued->channel,
                'expires_in_seconds' => $issued->expiresInSeconds,
                'resend_available_in_seconds' => $issued->resendAvailableInSeconds,
            ],
        ]);
    }

    public function destroy(DeleteAccountRequest $request, LoginCodeCheck $check, EraseCustomer $erase): Response
    {
        $customer = $this->customer($request);
        $phone = $this->phone($customer);
        $code = (string) $request->validated('code');

        // The code is spent inside the erasure, under its locks and after its
        // unfinished-order check, so a blocking order never costs it (`DL-140`).
        try {
            $erase->erase($customer, $customer, fn () => $check->consume($phone, $code, LoginChallenge::PURPOSE_ACCOUNT_DELETION));
        } catch (LoginCodeRefused $refusal) {
            throw $refusal->apiCode === 'code_locked'
                ? ApiException::tooManyRequests('code_locked', $refusal->retryAfterSeconds ?? LoginCodePolicy::LOCK_SECONDS)
                : ApiException::unprocessable($refusal->apiCode, $refusal->attemptsLeft === null ? [] : ['attempts_left' => $refusal->attemptsLeft]);
        }

        return response()->noContent();
    }

    private function refuseWhileUnfinished(User $customer): void
    {
        $order = UnfinishedOrders::oldest($customer);

        if ($order !== null) {
            throw ApiException::conflict('account_has_unfinished_orders', UnfinishedOrders::details($order));
        }
    }

    private function phone(User $customer): string
    {
        // An active Customer always has a phone; only a deleted account has none.
        assert($customer->phone !== null);

        return $customer->phone;
    }

    private function customer(EmptyBodyRequest|DeleteAccountRequest $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
