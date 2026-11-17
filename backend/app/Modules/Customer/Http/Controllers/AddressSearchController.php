<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Customer\Actions\DescribePoint;
use App\Modules\Customer\Actions\SearchAddress;
use App\Modules\Customer\Http\Requests\AddressReverseRequest;
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

    /**
     * `POST /customer/address-search/reverse` (`DL-138` item 3): the words
     * under a map point, for display only.
     */
    public function reverse(AddressReverseRequest $request, DescribePoint $describe): JsonResponse
    {
        $customer = $request->user();

        if (! $customer instanceof User) {
            abort(401);
        }

        $address = $describe(
            $customer,
            $request->string('latitude')->toString(),
            $request->string('longitude')->toString(),
            $request->string('language')->toString(),
        );

        return response()->json([
            'data' => $address === null ? null : ['line' => $address->line, 'house_known' => $address->houseKnown],
        ]);
    }
}
