<?php

namespace Tests\Feature\Routing;

use App\Support\Routing\ModuleRouteLoader;
use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\TestCase;

/**
 * The registry is what keeps concurrent tracks out of one shared route file, so
 * it has to be proven rather than inspected: that files are really required,
 * that their routes are really reachable, and that the two ways it can fail
 * quietly both fail loudly instead.
 */
class ModuleRouteLoaderTest extends TestCase
{
    private function fixture(string $name): string
    {
        return __DIR__.'/../../Fixtures/routes/'.$name;
    }

    public function test_it_loads_every_php_file_and_ignores_the_rest(): void
    {
        $loaded = ModuleRouteLoader::load($this->fixture('loads'));

        $this->assertCount(2, $loaded, 'Expected exactly the two .php fixtures.');

        $names = array_map('basename', $loaded);
        $this->assertSame(['10-first.php', '20-second.php'], $names);
        $this->assertNotContains('notes.txt', $names, 'A non-PHP file was loaded as a route file.');
    }

    public function test_it_loads_in_sorted_filename_order_not_filesystem_order(): void
    {
        $loaded = array_map('basename', ModuleRouteLoader::load($this->fixture('loads')));

        $sorted = $loaded;
        sort($sorted, SORT_STRING);

        $this->assertSame(
            $sorted,
            $loaded,
            'Files were not loaded in sorted order. Filesystem order differs between '
            .'Windows, the container and the CI runner, and route order decides which '
            .'overlapping pattern wins — so this defect would only appear elsewhere.'
        );
    }

    public function test_a_loaded_module_route_is_actually_registered_and_reachable(): void
    {
        ModuleRouteLoader::load($this->fixture('loads'));

        // The name lookup is a cache built when the router boots, so routes
        // required afterwards are invisible to getByName until it is refreshed.
        // Production never hits this: routes/api.php runs during boot.
        Route::getRoutes()->refreshNameLookups();

        $this->assertNotNull(Route::getRoutes()->getByName('fixture.first'));
        $this->assertNotNull(Route::getRoutes()->getByName('fixture.second'));

        $this->getJson('fixture/first')->assertOk()->assertJson(['module' => 'first']);
        $this->getJson('fixture/second')->assertOk()->assertJson(['module' => 'second']);
    }

    public function test_a_missing_directory_fails_loudly_and_names_the_path(): void
    {
        $missing = $this->fixture('does-not-exist');

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($missing);

        ModuleRouteLoader::load($missing);
    }

    public function test_an_empty_directory_registers_nothing_and_raises_nothing(): void
    {
        $before = count(Route::getRoutes()->getRoutes());

        $loaded = ModuleRouteLoader::load($this->fixture('empty'));

        $this->assertSame([], $loaded);
        $this->assertCount($before, Route::getRoutes()->getRoutes());
    }

    public function test_a_duplicate_route_name_across_modules_is_detectable(): void
    {
        ModuleRouteLoader::load($this->fixture('duplicate-names'));

        $withName = array_filter(
            Route::getRoutes()->getRoutes(),
            fn ($route) => $route->getName() === 'fixture.duplicate',
        );

        // Laravel lets the later registration win the name lookup silently. Two
        // tracks each naming a route `orders.show` would produce a route that
        // passes tests and resolves to the wrong controller in production, so
        // the collision has to be visible.
        $this->assertGreaterThan(
            1,
            count($withName),
            'Two modules registered the same route name and the collision left no trace.'
        );
    }

    public function test_the_production_api_surface_gains_no_endpoint(): void
    {
        // routes/api/v1/ holds only .gitkeep, so the real API is still empty and
        // an unknown path must still be the scope-safe not-found from S01-BE-001.
        $this->getJson('/api/v1/anything')
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
    }
}
