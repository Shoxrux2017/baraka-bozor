<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\BusinessSettings;
use App\Models\User;
use App\Modules\Settings\Actions\UpdateBusinessSettings;
use App\Modules\Settings\Http\Requests\UpdateBusinessSettingsRequest;
use App\Modules\Settings\Http\Resources\BusinessSettingsResource;
use Illuminate\Http\Request;

/**
 * `GET|PATCH /admin/settings/business` (`docs/09` section 44). Admin only; the
 * route declares it.
 */
final class BusinessSettingsController extends Controller
{
    public function show(): BusinessSettingsResource
    {
        return new BusinessSettingsResource(BusinessSettings::current());
    }

    public function update(UpdateBusinessSettingsRequest $request, UpdateBusinessSettings $update): BusinessSettingsResource
    {
        /** @var array<string, mixed> $changes */
        $changes = $request->validated();

        return new BusinessSettingsResource($update($this->admin($request), $changes));
    }

    private function admin(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            // Unreachable behind the protected group; stated for the type checker.
            abort(401);
        }

        return $user;
    }
}
