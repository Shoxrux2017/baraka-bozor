<?php

declare(strict_types=1);

namespace Tests\Fixtures\Modules;

/**
 * Records the order in which the fixture providers were registered.
 *
 * The registry's ordering guarantee is about what actually happens at boot, so
 * the test reads this log rather than the list of class names the registry
 * returned — a correct list registered in another order would be no guarantee at
 * all.
 *
 * This file sits beside the module directories rather than inside one, so the
 * registry's `<Module>/<Name>ServiceProvider.php` pattern never matches it.
 */
final class RegistrationLog
{
    /** @var list<string> */
    public static array $registered = [];

    public static function reset(): void
    {
        self::$registered = [];
    }

    public static function record(string $module): void
    {
        self::$registered[] = $module;
    }
}
