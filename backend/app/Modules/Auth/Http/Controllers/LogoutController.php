<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\User;
use Illuminate\Http\Response;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Revokes the caller's own token and nothing else — `docs/09-api-contracts.md`
 * Section 11. Other sessions of the same account, on other devices or in the
 * other mode of a phone holding two, keep working.
 */
final class LogoutController extends Controller
{
    public function __invoke(EmptyBodyRequest $request): Response
    {
        $user = $request->user();
        $token = $user instanceof User ? $user->currentAccessToken() : null;

        if ($token instanceof PersonalAccessToken) {
            $token->delete();
        }

        return response()->noContent();
    }
}
