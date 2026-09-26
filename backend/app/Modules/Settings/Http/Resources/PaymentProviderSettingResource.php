<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Resources;

use App\Models\PaymentProviderSetting;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One provider's enablement (`docs/09` section 44). Never a credential: there
 * is none in the table, and none may ever be added to this resource.
 *
 * @property-read PaymentProviderSetting $resource
 */
final class PaymentProviderSettingResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'provider' => $this->resource->provider,
            'is_enabled' => $this->resource->is_enabled,
            'updated_at' => $this->resource->updated_at->toIso8601ZuluString(),
        ];
    }
}
