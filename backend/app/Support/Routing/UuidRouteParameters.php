<?php

declare(strict_types=1);

namespace App\Support\Routing;

use Illuminate\Routing\Router;

/**
 * Every route parameter that carries a domain id is constrained to a UUID
 * before routing, so `orders/not-a-uuid` never reaches a query: a malformed
 * id is a route that does not match, which is the scope-safe
 * `404 resource_not_found` of `docs/09` Section 3 rather than a database error
 * rendered as `500`.
 *
 * The list is the contract: a module that introduces a new parameter name adds
 * it here, and `ProtectedRoutesTest` fails a production route whose parameter
 * is not in the list.
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

    public static function register(Router $router): void
    {
        foreach (self::NAMES as $name) {
            $router->pattern($name, self::PATTERN);
        }
    }
}
