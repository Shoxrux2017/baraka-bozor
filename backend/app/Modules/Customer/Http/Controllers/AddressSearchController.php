<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Customer\Actions\SearchAddress;
use App\Modules\Customer\Http\Requests\AddressSearchRequest;
use Illuminate\Http\JsonResponse;

/**
 * `POST /customer/address-search` (`docs/09` section 13). A Customer session;
 * the route declares it.
 */
final class AddressSearchController extends Controller
{
    public function store(AddressSearchRequest $request, SearchAddress $search): JsonResponse
    {
        $customer = $request->user();

        if (! $customer instanceof User) {
            abort(401);
        }

        $point = $search($customer, $request->string('query')->toString());

        return response()->json([
            'data' => $point === null ? null : ['latitude' => $point->latitude, 'longitude' => $point->longitude],
        ]);
    }
}
