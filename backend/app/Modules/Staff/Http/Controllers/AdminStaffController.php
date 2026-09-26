<?php

declare(strict_types=1);

namespace App\Modules\Staff\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\User;
use App\Modules\Staff\Actions\ActivateStaff;
use App\Modules\Staff\Actions\BlockStaff;
use App\Modules\Staff\Actions\CreateStaff;
use App\Modules\Staff\Actions\ResetStaffPassword;
use App\Modules\Staff\Http\Requests\CreateStaffRequest;
use App\Modules\Staff\Http\Requests\ListStaffRequest;
use App\Modules\Staff\Http\Requests\UpdateStaffRequest;
use App\Modules\Staff\Http\Resources\StaffResource;
use App\Modules\Staff\StaffDirectory;
use App\Modules\Staff\TemporaryCredentials;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `/admin/staff` (`docs/09` section 43, `docs/04` section 32). Admin only;
 * the route declares it.
 */
final class AdminStaffController extends Controller
{
    public function index(ListStaffRequest $request): JsonResponse
    {
        $query = StaffDirectory::staff()
            ->when($request->role(), fn ($query, $role) => $query->where('role', $role->value))
            ->when($request->status(), fn ($query, $status) => $query->where('status', $status->value))
            ->orderByDesc('created_at')
            ->orderBy('id');

        return PaginatedResponse::of(
            $query->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (User $staff): array => (new StaffResource($staff))->resolve($request),
        );
    }

    public function store(CreateStaffRequest $request, CreateStaff $create): JsonResponse
    {
        $credentials = $create($this->admin($request), $request->fullName(), $request->phone(), $request->role());

        return $this->withTemporaryPassword($request, $credentials, 201);
    }

    public function show(string $user): StaffResource
    {
        return new StaffResource($this->find($user));
    }

    public function update(UpdateStaffRequest $request, string $user): StaffResource
    {
        $staff = $this->find($user);
        $staff->forceFill(['full_name' => $request->validated('full_name')])->save();

        return new StaffResource($staff);
    }

    public function block(EmptyBodyRequest $request, string $user, BlockStaff $block): StaffResource
    {
        return new StaffResource($block($this->admin($request), $user));
    }

    public function activate(EmptyBodyRequest $request, string $user, ActivateStaff $activate): StaffResource
    {
        return new StaffResource($activate($user));
    }

    public function resetPassword(EmptyBodyRequest $request, string $user, ResetStaffPassword $reset): JsonResponse
    {
        return $this->withTemporaryPassword($request, $reset($this->admin($request), $user), 200);
    }

    /**
     * The one response that carries a temporary password: never cached by the
     * browser or anything between it and the server.
     */
    private function withTemporaryPassword(Request $request, TemporaryCredentials $credentials, int $status): JsonResponse
    {
        return response()
            ->json(['data' => [
                'user' => (new StaffResource($credentials->staff))->resolve($request),
                'temporary_password' => $credentials->password,
            ]], $status)
            ->header('Cache-Control', 'no-store');
    }

    private function find(string $id): User
    {
        return ScopedLookup::firstOrNotFound(StaffDirectory::staff()->whereKey($id));
    }

    private function admin(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
