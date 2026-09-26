<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\CustomerAddress;
use App\Models\User;
use App\Modules\Customer\Actions\SaveAddress;
use App\Modules\Customer\Http\Requests\AddressRequest;
use App\Modules\Customer\Http\Requests\ListAddressesRequest;
use App\Modules\Customer\Http\Resources\AddressResource;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * `/customer/addresses` (`docs/09` section 13). Own, active addresses only:
 * another Customer's address, a deactivated one and a missing one are the
 * same scope-safe `404`.
 */
final class AddressController extends Controller
{
    public function index(ListAddressesRequest $request): JsonResponse
    {
        $query = SaveAddress::own($this->customer($request))->orderByDesc('created_at')->orderBy('id');

        return PaginatedResponse::of(
            $query->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (CustomerAddress $address): array => (new AddressResource($address))->resolve($request),
        );
    }

    public function store(AddressRequest $request, SaveAddress $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return (new AddressResource($save->create($this->customer($request), $fields)))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, string $address): AddressResource
    {
        return new AddressResource(
            ScopedLookup::firstOrNotFound(SaveAddress::own($this->customer($request))->whereKey($address))
        );
    }

    public function update(AddressRequest $request, string $address, SaveAddress $save): AddressResource
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return new AddressResource($save->update($this->customer($request), $address, $fields));
    }

    public function destroy(Request $request, string $address, SaveAddress $save): Response
    {
        $save->deactivate($this->customer($request), $address);

        return response()->noContent();
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
