<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Notifications\Actions\RegisterPushDevice;
use App\Modules\Notifications\Http\Requests\RegisterPushDeviceRequest;
use App\Modules\Notifications\Http\Resources\PushDeviceResource;
use App\Support\Scope\ScopedLookup;
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
    public function destroy(Request $request, string $device): Response
    {
        $pushDevice = ScopedLookup::firstOrNotFound(
            PushDevice::query()->where('user_id', $this->account($request)->id)->whereKey($device)
        );

        if ($pushDevice->revoked_at === null) {
            $pushDevice->forceFill(['revoked_at' => now()])->save();
        }

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
