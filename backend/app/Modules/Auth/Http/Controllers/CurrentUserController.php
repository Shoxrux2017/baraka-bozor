<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Auth\Http\Requests\UpdateCurrentUserRequest;
use App\Modules\Auth\Http\Resources\CurrentUserResource;
use Illuminate\Http\Request;

final class CurrentUserController extends Controller
{
    public function show(Request $request): CurrentUserResource
    {
        return new CurrentUserResource($this->user($request));
    }

    public function update(UpdateCurrentUserRequest $request): CurrentUserResource
    {
        $user = $this->user($request);

        $user->fill(['preferred_language' => (string) $request->validated('preferred_language')])->save();

        return new CurrentUserResource($user);
    }

    private function user(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            // Unreachable behind auth:sanctum; stated for the type checker and
            // for anyone who mounts this controller without it.
            abort(401);
        }

        return $user;
    }
}
