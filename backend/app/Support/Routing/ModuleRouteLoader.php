<?php

namespace App\Support\Routing;

use RuntimeException;

/**
 * Collects per-module route files so that concurrent tracks never edit one
 * shared route file.
 *
 * A module declares its endpoints in `routes/api/v1/<module>.php`. This loader
 * requires every such file, which is what `routes/api.php` does instead of
 * declaring routes itself. The prefix comes from `bootstrap/app.php`, so a
 * module file must not add `/api/v1` again.
 *
 * Decision `D-8` of the execution-model design record, approved 2026-09-21.
 */
final class ModuleRouteLoader
{
    /**
     * Require every `*.php` file in $directory, in sorted filename order.
     *
     * Order is sorted rather than filesystem order on purpose. `glob()` returns
     * whatever the filesystem gives, which differs between a developer's
     * machine, the container and the CI runner — and route order decides which
     * pattern wins when two overlap. An unsorted loader is a defect that only
     * appears on someone else's machine.
     *
     * @return list<string> the files loaded, in the order they were loaded
     *
     * @throws RuntimeException when $directory does not exist
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

        // An empty directory is legitimate: it is the state immediately after
        // the registry is introduced and before the first module exists.
        sort($files, SORT_STRING);

        foreach ($files as $file) {
            require $file;
        }

        // sort() reindexes in place, so $files is already a list here.
        return $files;
    }
}
