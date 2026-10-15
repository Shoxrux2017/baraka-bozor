<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Auth\Actions\RequestCustomerLoginCode;
use App\Modules\Auth\Actions\VerifyCustomerLoginCode;
use App\Modules\Auth\Http\Requests\RequestCustomerLoginCodeRequest;
use App\Modules\Auth\Http\Requests\VerifyCustomerLoginCodeRequest;
use App\Modules\Auth\Http\Resources\CurrentUserResource;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;

final class CustomerLoginCodeController extends Controller
{
    public function request(RequestCustomerLoginCodeRequest $request, RequestCustomerLoginCode $requestCode): JsonResponse
    {
        $issued = $requestCode((string) $request->validated('phone'), (string) $request->ip());

        return new JsonResponse([
            'data' => [
                'channel' => $issued->channel,
                'expires_in_seconds' => $issued->expiresInSeconds,
                'resend_available_in_seconds' => $issued->resendAvailableInSeconds,
            ],
        ]);
    }

    public function verify(VerifyCustomerLoginCodeRequest $request, VerifyCustomerLoginCode $verify): JsonResponse
    {
        $login = $verify((string) $request->validated('phone'), (string) $request->validated('code'));
        $session = $login->customer;

        return new JsonResponse([
            'data' => [
                'token' => $session->token,
                'user' => (new CurrentUserResource($session->user))->resolve($request),
                'staff_step' => $login->staffStepToken === null || $login->staffStepExpiresAt === null ? null : [
                    'token' => $login->staffStepToken,
                    'expires_at' => CarbonImmutable::instance($login->staffStepExpiresAt)->toIso8601ZuluString(),
                ],
            ],
        ]);
    }
}
