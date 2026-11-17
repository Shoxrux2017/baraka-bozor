<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\BusinessSettings;
use Illuminate\Http\JsonResponse;

/**
 * `GET /customer/service-area` (`docs/09` section 13, `DL-138` item 5): the
 * circle the map draws. A preview only; the server still refuses a saved point
 * outside it. A Customer session; the route declares it.
 */
final class ServiceAreaController extends Controller
{
    public function show(): JsonResponse
    {
        $settings = BusinessSettings::current();

        if ($settings->service_centre_latitude === null
            || $settings->service_centre_longitude === null
            || $settings->service_radius_km === null) {
            return response()->json(['data' => null]);
        }

        return response()->json(['data' => [
            'latitude' => $settings->service_centre_latitude,
            'longitude' => $settings->service_centre_longitude,
            'radius_km' => $settings->service_radius_km,
        ]]);
    }
}
