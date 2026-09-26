<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Notifications\Actions\RegisterPushDevice;
use App\Modules\Notifications\Actions\RevokePushDevice;
use App\Modules\Notifications\Http\Requests\RegisterPushDeviceRequest;
use App\Modules\Notifications\Http\Resources\PushDeviceResource;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * `POST /push-devices`, `DELETE /push-devices/{device}` (`docs/09`
 * section 27). Any signed-in account, for its own devices only.
 */
final class PushDeviceController extends Controller
{
    public function store(RegisterPushDeviceRequest $request, RegisterPushDevice $register): PushDeviceResource
    {
        return new PushDeviceResource($register($this->account($request), $request->platform(), $request->token()));
    }

    /**
     * Revoking is idempotent for the owner: a device already revoked answers
     * `204` again, so a client that retries a logout is not told otherwise.
     */
    public function destroy(Request $request, string $device, RevokePushDevice $revoke): Response
    {
        $revoke($this->account($request), $device);

        return response()->noContent();
    }

    private function account(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
