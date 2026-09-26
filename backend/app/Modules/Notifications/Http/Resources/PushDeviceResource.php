<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Http\Resources;

use App\Models\PushDevice;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A registered device (`docs/09` section 27): the id the client keeps to
 * revoke it later. The token itself is not echoed back; the client already
 * holds it, and nothing else should read it from a response.
 *
 * @property-read PushDevice $resource
 */
final class PushDeviceResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $device = $this->resource;

        return [
            'id' => $device->id,
            'platform' => $device->platform->value,
            'last_seen_at' => $device->last_seen_at?->toIso8601ZuluString(),
            'created_at' => $device->created_at->toIso8601ZuluString(),
        ];
    }
}
