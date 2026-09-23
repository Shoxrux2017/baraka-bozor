<?php

declare(strict_types=1);

namespace App\Support\Modules;

use FilesystemIterator;
use Illuminate\Support\ServiceProvider;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RuntimeException;
use SplFileInfo;

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
 * with the matching PSR-4 class, and nothing edits the shared list. A module with
 * no provider at all is fine — plenty have routes and no bindings.
 *
 * What fails loudly: a missing modules root, a provider file whose class does not
 * match the path, a class that is not a service provider, and a provider placed
 * below its module directory instead of directly in it. What cannot be caught is
 * a provider class that is not named `*ServiceProvider`, since telling it apart
 * from an ordinary class would mean loading every file in the tree.
 */
final class ModuleProviderRegistry
{
    /**
     * Every module service provider under $directory, in registration order.
     *
     * @param  string  $directory  the modules root, e.g. `app/Modules`
     * @param  string  $namespace  the PSR-4 namespace that root maps to, e.g. `App\Modules`
     * @return list<class-string<ServiceProvider>>
     *
     * @throws RuntimeException when the root is missing or unreadable, when a
     *                          provider sits below its module directory, when a
     *                          provider file has no matching PSR-4 class, or when
     *                          that class is not a service provider
     */
    public static function discover(string $directory, string $namespace): array
    {
        if (! is_dir($directory)) {
            // Loud on purpose. A missing root means every module's bindings have
            // disappeared at once, and nothing else would say so.
            throw new RuntimeException(
                "Module directory is missing: {$directory}. ".
                'Every module registers its bindings through a provider inside it, so an '.
                'absent directory means no module is wired up at all.'
            );
        }

        $entries = [];

        foreach (self::subdirectoriesOf($directory) as $moduleDirectory) {
            self::refuseProvidersBelow($moduleDirectory);

            $module = basename($moduleDirectory);

            foreach (self::providerFilesIn($moduleDirectory) as $file) {
                $entries[] = [$module, basename($file, '.php')];
            }
        }

        $providers = [];

        foreach (self::inRegistrationOrder($entries) as [$module, $class]) {
            $providers[] = self::qualify($directory, $namespace, $module, $class);
        }

        return $providers;
    }

    /**
     * Put provider entries into the order they will be registered in.
     *
     * Exposed rather than kept private because it is the one guarantee here that
     * a test driven by the filesystem cannot check. The order is taken over the
     * `[module, class]` segments and never over the joined path, because a path
     * comparison includes the directory separator: on Linux `/` is `0x2F`, below
     * every letter, so `Auth/…` sorts before `AuthExtra/…`; on Windows `\` is
     * `0x5C`, above every uppercase letter, so the two swap. One module name
     * being a prefix of another is all it takes. The suite runs only inside the
     * Linux container, so the platform that would notice never runs it.
     *
     * `strcmp` rather than `<=>`, which compares two numeric strings numerically.
     *
     * @param  list<array{string, string}>  $entries
     * @return list<array{string, string}>
     */
    public static function inRegistrationOrder(array $entries): array
    {
        usort(
            $entries,
            static fn (array $a, array $b): int => strcmp($a[0], $b[0]) ?: strcmp($a[1], $b[1])
        );

        return $entries;
    }

    /**
     * @return list<string>
     */
    private static function subdirectoriesOf(string $directory): array
    {
        $found = glob($directory.DIRECTORY_SEPARATOR.'*', GLOB_ONLYDIR);

        if ($found === false) {
            throw new RuntimeException("Module directory could not be read: {$directory}.");
        }

        return $found;
    }

    /**
     * @return list<string>
     */
    private static function providerFilesIn(string $moduleDirectory): array
    {
        $found = glob($moduleDirectory.DIRECTORY_SEPARATOR.'*ServiceProvider.php');

        if ($found === false) {
            throw new RuntimeException("Module directory could not be read: {$moduleDirectory}.");
        }

        return $found;
    }

    /**
     * Refuse a provider placed anywhere below the module directory itself.
     *
     * `Auth/Providers/AuthServiceProvider.php` is the layout several Laravel
     * packages use, so it is the mistake to expect. Discovery looks exactly one
     * level down, so without this the file is skipped in silence and the module's
     * bindings simply never exist — surfacing much later as a
     * `BindingResolutionException` at request time, nowhere near the cause.
     */
    private static function refuseProvidersBelow(string $moduleDirectory): void
    {
        foreach (self::subdirectoriesOf($moduleDirectory) as $nested) {
            $files = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($nested, FilesystemIterator::SKIP_DOTS)
            );

            foreach ($files as $file) {
                /** @var SplFileInfo $file */
                if ($file->isFile() && str_ends_with($file->getFilename(), 'ServiceProvider.php')) {
                    throw new RuntimeException(sprintf(
                        'Module provider %s is below its module directory. A provider must sit '
                        .'directly in %s, because that is the only place the registry looks — '
                        .'anywhere deeper is skipped without a word.',
                        $file->getPathname(),
                        $moduleDirectory
                    ));
                }
            }
        }
    }

    /**
     * The PSR-4 class a provider file must declare.
     *
     * @return class-string<ServiceProvider>
     */
    private static function qualify(string $directory, string $namespace, string $module, string $class): string
    {
        $qualified = $namespace.'\\'.$module.'\\'.$class;

        if (! class_exists($qualified)) {
            // The one mistake this layout invites: the right file in the right
            // place with the wrong namespace inside it. The autoloader never
            // finds it, so without this the module is silently skipped.
            throw new RuntimeException(sprintf(
                'Module provider %s declares no class %s. A provider file must declare the '
                .'PSR-4 class its path implies, or the autoloader will never find it.',
                $directory.DIRECTORY_SEPARATOR.$module.DIRECTORY_SEPARATOR.$class.'.php',
                $qualified
            ));
        }

        if (! is_subclass_of($qualified, ServiceProvider::class)) {
            throw new RuntimeException(sprintf(
                '%s is named like a service provider but does not extend %s, so the application '
                .'cannot register it.',
                $qualified,
                ServiceProvider::class
            ));
        }

        return $qualified;
    }
}
