<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Auth\Actions\AuthenticateStaffStep;
use App\Modules\Auth\Http\Requests\StaffStepRequest;
use App\Modules\Auth\Http\Resources\CurrentUserResource;
use Illuminate\Http\JsonResponse;

final class StaffStepController extends Controller
{
    public function __invoke(StaffStepRequest $request, AuthenticateStaffStep $authenticate): JsonResponse
    {
        $session = $authenticate(
            (string) $request->validated('staff_step'),
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
