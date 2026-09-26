<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Customer\Http\Requests\UpdateProfileRequest;
use App\Modules\Customer\Http\Resources\ProfileResource;
use Illuminate\Http\Request;

/**
 * `GET|PATCH /customer/profile` (`docs/09` section 12). A Customer session;
 * the route declares it.
 */
final class ProfileController extends Controller
{
    public function show(Request $request): ProfileResource
    {
        return new ProfileResource($this->customer($request));
    }

    public function update(UpdateProfileRequest $request): ProfileResource
    {
        $customer = $this->customer($request);

        /** @var array<string, mixed> $fields */
        $fields = $request->validated();
        $customer->fill($fields)->save();

        return new ProfileResource($customer);
    }

    private function customer(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
