<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Auth\Actions\AuthenticateStaff;
use App\Modules\Auth\Http\Requests\StaffLoginRequest;
use App\Modules\Auth\Http\Resources\CurrentUserResource;
use Illuminate\Http\JsonResponse;

final class StaffLoginController extends Controller
{
    public function __invoke(StaffLoginRequest $request, AuthenticateStaff $authenticate): JsonResponse
    {
        $session = $authenticate(
            (string) $request->validated('phone'),
            (string) $request->validated('password'),
            (string) $request->ip(),
        );

        return new JsonResponse([
            'data' => [
                'token' => $session->token,
                'user' => (new CurrentUserResource($session->user))->resolve($request),
            ],
        ]);
    }
}
