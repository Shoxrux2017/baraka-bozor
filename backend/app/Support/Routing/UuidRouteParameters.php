<?php

declare(strict_types=1);

namespace App\Support\Routing;

use App\Models\Enums\PaymentProvider;
use BackedEnum;
use Illuminate\Routing\Router;

/**
 * Every route parameter is constrained before routing, so `orders/not-a-uuid`
 * never reaches a query: a malformed value is a route that does not match,
 * which is the scope-safe `404 resource_not_found` of `docs/09` Section 3
 * rather than a database error rendered as `500`.
 *
 * Two kinds of parameter exist. A domain id is a UUID (`DL-12`). A closed set
 * of values — the four payment providers — is constrained to exactly those
 * values (`DL-17` (13)), derived from the enum so the two cannot drift.
 *
 * The lists are the contract: a module that introduces a new parameter name
 * adds it here, and `ProtectedRoutesTest` fails a production route whose
 * parameter is in neither list or carries a different pattern.
 */
final class UuidRouteParameters
{
    public const PATTERN = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

    /** @var list<string> */
    public const NAMES = [
        'id',
        'user',
        'address',
        'category',
        'product',
        'item',
        'order',
        'approval',
        'request',
        'payment',
        'refund',
        'device',
    ];

    /**
     * Parameters constrained to the values of a backed enum.
     *
     * @var array<string, class-string<BackedEnum>>
     */
    public const ENUMS = [
        'provider' => PaymentProvider::class,
    ];

    public static function register(Router $router): void
    {
        foreach (self::NAMES as $name) {
            $router->pattern($name, self::PATTERN);
        }

        foreach (self::ENUMS as $name => $enum) {
            $router->pattern($name, self::enumPattern($enum));
        }
    }

    /**
     * The route pattern admitting exactly the enum's values.
     *
     * @param  class-string<BackedEnum>  $enum
     */
    public static function enumPattern(string $enum): string
    {
        return implode('|', array_map(
            static fn (BackedEnum $case): string => preg_quote((string) $case->value, '/'),
            $enum::cases()
        ));
    }
}
