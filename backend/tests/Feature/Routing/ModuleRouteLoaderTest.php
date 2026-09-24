<?php

declare(strict_types=1);

namespace Tests\Feature\Routing;

use App\Support\Routing\ModuleRouteLoader;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\TestCase;

/**
 * The registry is what keeps concurrent tracks out of one shared route file, so
 * it has to be proven rather than inspected: that files are really required in a
 * fixed order, that a module's routes really land under `/api/v1` with the `api`
 * middleware, and that the three ways this can go wrong quietly all go wrong
 * loudly instead.
 *
 * Module files are written at run time rather than committed. Two reasons. They
 * declare routes at file top level, which is fine for a route file and odd for
 * anything under `tests/` that static analysis walks. And writing them here lets
 * a test control creation order, so the sorted-order assertion can actually fail
 * if the sort is removed.
 */
final class ModuleRouteLoaderTest extends TestCase
{
    private string $root;

    protected function setUp(): void
    {
        parent::setUp();

        $this->root = sys_get_temp_dir().'/module-route-loader-'.bin2hex(random_bytes(6));
        File::makeDirectory($this->root, 0755, true);
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->root);

        parent::tearDown();
    }

    /**
     * @param  array<string, string>  $files  filename => PHP body after `<?php`
     */
    private function moduleDirectory(string $name, array $files = []): string
    {
        $directory = $this->root.'/'.$name;
        File::makeDirectory($directory, 0755, true);

        foreach ($files as $filename => $body) {
            File::put($directory.'/'.$filename, "<?php\n\n".$body);
        }

        return $directory;
    }

    private function routeFile(string $uri, string $routeName, string $payload): string
    {
        return sprintf(
            "use Illuminate\\Support\\Facades\\Route;\n\n".
            "Route::get('%s', fn () => response()->json(['module' => '%s']))->name('%s');\n",
            $uri,
            $payload,
            $routeName,
        );
    }

    /**
     * Loads a directory the way bootstrap/app.php loads the real one, so the
     * prefix and middleware under test are the production ones.
     *
     * @return list<string>
     */
    private function loadMounted(string $directory): array
    {
        $loaded = [];

        Route::middleware('api')->prefix('api/v1')->group(function () use ($directory, &$loaded): void {
            $loaded = ModuleRouteLoader::load($directory);
        });

        // The name lookup is a cache built when the router boots, so routes
        // required afterwards are invisible to getByName until it is refreshed.
        // Production never hits this: routes/api.php runs during boot.
        Route::getRoutes()->refreshNameLookups();

        return $loaded;
    }

    public function test_it_loads_every_php_file_in_sorted_order_and_ignores_the_rest(): void
    {
        // Created in reverse order on purpose: if the loader trusted creation or
        // directory order instead of sorting, this test would fail.
        $directory = $this->moduleDirectory('loads', [
            '20-second.php' => $this->routeFile('fixture/second', 'fixture.second', 'second'),
            '10-first.php' => $this->routeFile('fixture/first', 'fixture.first', 'first'),
        ]);
        File::put($directory.'/notes.txt', 'Not a PHP file. The loader must ignore it.');

        $loaded = $this->loadMounted($directory);

        $this->assertSame(
            ['10-first.php', '20-second.php'],
            array_map('basename', $loaded),
            'Expected exactly the two .php files, in sorted filename order.'
        );
    }

    public function test_a_module_route_lands_under_api_v1_with_the_api_middleware(): void
    {
        $this->loadMounted($this->moduleDirectory('mounted', [
            '10-first.php' => $this->routeFile('fixture/first', 'fixture.first', 'first'),
        ]));

        $route = Route::getRoutes()->getByName('fixture.first');

        $this->assertNotNull($route, 'The module route was not registered at all.');
        $this->assertSame('api/v1/fixture/first', $route->uri(), 'The /api/v1 prefix was lost or applied twice.');
        $this->assertContains('api', $route->gatherMiddleware(), 'The api middleware group was not inherited.');

        // This is the property every feature task depends on: drop a file in
        // routes/api/v1/ and its routes are served under /api/v1, once.
        $this->getJson('/api/v1/fixture/first')->assertOk()->assertJson(['module' => 'first']);
    }

    public function test_a_missing_directory_fails_loudly_and_names_the_path(): void
    {
        $missing = $this->root.'/does-not-exist';

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($missing);

        ModuleRouteLoader::load($missing);
    }

    public function test_an_empty_directory_registers_nothing_and_raises_nothing(): void
    {
        $before = count(Route::getRoutes()->getRoutes());

        $loaded = ModuleRouteLoader::load($this->moduleDirectory('empty'));

        $this->assertSame([], $loaded);
        $this->assertCount($before, Route::getRoutes()->getRoutes());
    }

    public function test_a_duplicate_route_name_across_modules_stops_the_boot(): void
    {
        $directory = $this->moduleDirectory('duplicate-names', [
            'a-module.php' => $this->routeFile('duplicate/a', 'fixture.duplicate', 'a'),
            'b-module.php' => $this->routeFile('duplicate/b', 'fixture.duplicate', 'b'),
        ]);

        // Two tracks each naming a route `orders.show` would otherwise leave the
        // suite green while one module's route became unreachable by name and
        // route() resolved to the other module's controller.
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('fixture.duplicate');
        $this->expectExceptionMessage('a-module.php');
        $this->expectExceptionMessage('b-module.php');

        ModuleRouteLoader::load($directory);
    }

    public function test_the_production_api_surface_comes_from_module_files_only(): void
    {
        // routes/api.php is the loader and declares nothing itself; every
        // endpoint under /api/v1 comes from a module file and is named, which
        // is what lets a duplicate name anywhere stop the boot.
        $source = (string) file_get_contents(base_path('routes/api.php'));

        $this->assertStringNotContainsString('Route::', $source, 'routes/api.php must declare no route of its own.');
        $this->assertStringContainsString("ModuleRouteLoader::load(__DIR__.'/api/v1')", $source);

        $apiRoutes = array_filter(
            Route::getRoutes()->getRoutes(),
            fn ($route) => str_starts_with($route->uri(), 'api/v1'),
        );

        $this->assertNotEmpty($apiRoutes, 'The auth module declares the first production endpoints.');

        foreach ($apiRoutes as $route) {
            $this->assertNotEmpty($route->getName(), "Route {$route->uri()} must be named by its module file.");
        }
    }
}
