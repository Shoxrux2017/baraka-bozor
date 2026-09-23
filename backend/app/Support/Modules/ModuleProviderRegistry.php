<?php

declare(strict_types=1);

namespace App\Support\Modules;

use Illuminate\Support\ServiceProvider;
use RuntimeException;

/**
 * Collects each module's service provider so that concurrent tracks never edit
 * one shared provider list.
 *
 * This is decision `D-8` carried from route files to container bindings.
 * `ModuleRouteLoader` already keeps each module's endpoints in
 * `routes/api/v1/<module>.php`; `bootstrap/providers.php` was the same problem
 * left open. A module that needs a binding, an observer, a policy or a validation
 * rule has to be listed somewhere, and if that somewhere is one shared file then
 * two tracks add a line each and collide, in every wave, forever.
 *
 * A module declares its provider at `app/Modules/<Module>/<Name>ServiceProvider.php`
 * with the matching PSR-4 class, and nothing edits the shared list.
 *
 * Every way this can go wrong fails loudly. A provider that is quietly skipped
 * takes its module's bindings with it, and what surfaces is a container
 * resolution error somewhere else entirely, long after the cause.
 */
final class ModuleProviderRegistry
{
    /**
     * Every module service provider under $directory, in sorted order.
     *
     * @param  string  $directory  the modules root, e.g. `app/Modules`
     * @param  string  $namespace  the PSR-4 namespace that root maps to, e.g. `App\Modules`
     * @return list<class-string<ServiceProvider>>
     *
     * @throws RuntimeException when the directory is missing or unreadable, when a
     *                          provider file has no matching PSR-4 class, or when
     *                          that class is not a service provider
     */
    public static function discover(string $directory, string $namespace): array
    {
        if (! is_dir($directory)) {
            // Loud on purpose. A missing directory means every module's bindings
            // have disappeared at once, and nothing else would say so.
            throw new RuntimeException(
                "Module directory is missing: {$directory}. ".
                'Every module registers its bindings through a provider inside it, so an '.
                'absent directory means no module is wired up at all.'
            );
        }

        $files = glob($directory.DIRECTORY_SEPARATOR.'*'.DIRECTORY_SEPARATOR.'*ServiceProvider.php');

        if ($files === false) {
            throw new RuntimeException("Module directory could not be read: {$directory}.");
        }

        // `glob()` already sorts, but through the C library's collation, which
        // depends on the runtime locale. `SORT_STRING` compares bytes, so the
        // order is the same on every machine. Registration order decides which
        // binding wins when two modules bind the same key, so it must not vary
        // between a developer's machine and CI.
        sort($files, SORT_STRING);

        $providers = [];

        foreach ($files as $file) {
            $providers[] = self::classFor($file, $directory, $namespace);
        }

        return $providers;
    }

    /**
     * The PSR-4 class a provider file must declare.
     *
     * @return class-string<ServiceProvider>
     */
    private static function classFor(string $file, string $directory, string $namespace): string
    {
        $module = basename(dirname($file));
        $class = $namespace.'\\'.$module.'\\'.basename($file, '.php');

        if (! class_exists($class)) {
            // The one mistake this layout invites: the right file in the right
            // place with the wrong namespace inside it. The autoloader never
            // finds it, so without this the module is silently skipped.
            throw new RuntimeException(sprintf(
                'Module provider %s declares no class %s. A provider file must declare the '
                .'PSR-4 class its path implies, or the autoloader will never find it.',
                $file,
                $class
            ));
        }

        if (! is_subclass_of($class, ServiceProvider::class)) {
            throw new RuntimeException(sprintf(
                '%s is named like a service provider but does not extend %s, so the application '
                .'cannot register it.',
                $class,
                ServiceProvider::class
            ));
        }

        return $class;
    }
}
