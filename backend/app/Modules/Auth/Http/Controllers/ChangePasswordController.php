<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Auth\Actions\ChangePassword;
use App\Modules\Auth\Http\Requests\ChangePasswordRequest;
use Illuminate\Http\Response;
use Laravel\Sanctum\PersonalAccessToken;

final class ChangePasswordController extends Controller
{
    public function __invoke(ChangePasswordRequest $request, ChangePassword $changePassword): Response
    {
        $user = $request->user();
        $token = $user instanceof User ? $user->currentAccessToken() : null;

        // A Customer has no password to change, and a session that is not a
        // bearer token has no counter to key the limit to. Neither is a
        // caller this endpoint serves.
        if (! $user instanceof User || ! $user->isStaff() || ! $token instanceof PersonalAccessToken) {
            throw ApiException::forbidden('forbidden');
        }

        $changePassword(
            $user,
            $token,
            (string) $request->validated('current_password'),
            (string) $request->validated('new_password'),
        );

        return response()->noContent();
    }
}
