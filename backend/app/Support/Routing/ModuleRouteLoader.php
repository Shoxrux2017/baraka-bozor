<?php

declare(strict_types=1);

namespace App\Support\Routing;

use Illuminate\Support\Facades\Route;
use RuntimeException;

/**
 * Collects per-module route files so that concurrent tracks never edit one
 * shared route file.
 *
 * A module declares its endpoints in `routes/api/v1/<module>.php`. This loader
 * requires every such file, which is what `routes/api.php` does instead of
 * declaring routes itself. The prefix and middleware come from the group
 * `bootstrap/app.php` opens, and a nested `require` runs inside that group, so a
 * module file must not repeat `/api/v1`. It must also use the `Route` facade:
 * the `$router` variable Laravel exposes to `routes/api.php` is not in scope in
 * a file required from here.
 *
 * Decision `D-8` of the execution-model design record, approved 2026-09-21.
 */
final class ModuleRouteLoader
{
    /**
     * Require every `*.php` file in $directory, in sorted filename order.
     *
     * @return list<string> the files loaded, in the order they were loaded
     *
     * @throws RuntimeException when $directory is missing, unreadable, or two
     *                          files register the same route name
     */
    public static function load(string $directory): array
    {
        if (! is_dir($directory)) {
            // Loud on purpose. A missing directory means every endpoint has
            // silently disappeared, and a silently empty API is the failure
            // mode this wave has already met twice.
            throw new RuntimeException(
                "Module route directory is missing: {$directory}. ".
                'Every API endpoint is declared in a file inside it, so an '.
                'absent directory means the API has no routes at all.'
            );
        }

        $files = glob($directory.DIRECTORY_SEPARATOR.'*.php');

        if ($files === false) {
            throw new RuntimeException("Module route directory could not be read: {$directory}.");
        }

        // `glob()` already sorts alphabetically, but through the C library's
        // collation, which depends on the runtime locale. `SORT_STRING` compares
        // bytes, so the order is the same on every machine. Route order decides
        // which pattern wins when two overlap, so it must not vary.
        sort($files, SORT_STRING);

        /** @var array<string, string> $owner route name => file that registered it */
        $owner = [];

        foreach ($files as $file) {
            $before = self::routeNameCounts();

            require $file;

            foreach (self::namesAddedSince($before) as $name) {
                if (isset($owner[$name])) {
                    // Laravel keeps the FIRST registration of a name — see
                    // RouteCollection::addLookups, which guards with
                    // `! $this->inNameLookup($name)`. So the second module's
                    // named route becomes unreachable by name while `route($name)`
                    // silently resolves to the first module's controller. Which
                    // module wins depends on filename sort order. Two tracks
                    // could each name a route `orders.show` and the suite would
                    // stay green, so this has to stop the boot instead.
                    throw new RuntimeException(sprintf(
                        'Duplicate API route name "%s": registered by %s and again by %s. '.
                        'Route names must be unique across modules — Laravel keeps the first '.
                        'registration, so the second route becomes unreachable by name and '.
                        'route("%s") resolves to the first module.',
                        $name,
                        basename((string) $owner[$name]),
                        basename($file),
                        $name,
                    ));
                }

                $owner[$name] = $file;
            }
        }

        // An empty directory is legitimate: it is the state immediately after
        // the registry is introduced and before the first module exists.
        // `sort()` reindexes in place, so $files is already a list here.
        return $files;
    }

    /**
     * How many registered routes currently carry each name.
     *
     * Counted rather than listed because a name can legitimately appear once and
     * illegitimately appear twice, and because registering a route may replace
     * an existing one rather than append, so positions are not stable.
     *
     * @return array<string, int>
     */
    private static function routeNameCounts(): array
    {
        $counts = [];

        foreach (Route::getRoutes()->getRoutes() as $route) {
            $name = $route->getName();

            if ($name !== null && $name !== '') {
                $counts[$name] = ($counts[$name] ?? 0) + 1;
            }
        }

        return $counts;
    }

    /**
     * Names whose route count grew since $before.
     *
     * @param  array<string, int>  $before
     * @return list<string>
     */
    private static function namesAddedSince(array $before): array
    {
        $added = [];

        foreach (self::routeNameCounts() as $name => $count) {
            if ($count > ($before[$name] ?? 0)) {
                $added[] = $name;
            }
        }

        return $added;
    }
}
