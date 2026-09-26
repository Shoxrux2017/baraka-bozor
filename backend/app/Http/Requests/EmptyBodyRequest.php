<?php

declare(strict_types=1);

namespace App\Http\Requests;

/**
 * The request of an action that takes no body: archive, restore, block,
 * activate, a password reset, a logout, a delete. `docs/09-api-contracts.md`
 * section 4 refuses unknown fields on every mutation, and every field sent
 * here is one, so a client that believes it is saying something — a reason, a
 * flag — learns that it is not heard (`DL-31`).
 */
final class EmptyBodyRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [];
    }
}
