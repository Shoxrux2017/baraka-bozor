<?php

declare(strict_types=1);

namespace Tests\Feature\Modules;

use App\Providers\AppServiceProvider;
use App\Support\Modules\ModuleProviderRegistry;
use Illuminate\Support\Facades\File;
use RuntimeException;
use Tests\Fixtures\Modules\RegistrationLog;
use Tests\TestCase;

/**
 * The registry extends decision `D-8` from route files to container bindings.
 *
 * `D-8` gave each module its own route file so that concurrent tracks never edit
 * one shared file. `bootstrap/providers.php` was the same problem left open: a
 * module that needs a binding, an observer or a policy has to be listed there,
 * and two tracks adding a line each collide on one file in every wave. A module
 * now declares its provider inside its own directory and nothing edits the
 * shared list.
 *
 * Registration is proven here by the container answering, never by inspecting
 * what the registry returned. A correct list of class names that nothing ever
 * registers would satisfy the second and fail the first.
 */
final class ModuleProviderRegistryTest extends TestCase
{
    private const FIXTURE_NAMESPACE = 'Tests\\Fixtures\\Modules';

    private string $temporaryRoot;

    protected function setUp(): void
    {
        parent::setUp();

        RegistrationLog::reset();

        $this->temporaryRoot = sys_get_temp_dir().'/module-provider-registry-'.bin2hex(random_bytes(6));
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->temporaryRoot);

        RegistrationLog::reset();

        parent::tearDown();
    }

    private function fixtures(string $root = 'Modules'): string
    {
        return base_path('tests/Fixtures/'.$root);
    }

    public function test_it_finds_the_provider_inside_each_module_directory(): void
    {
        $this->assertSame(
            [
                'Tests\Fixtures\Modules\Alpha\AlphaServiceProvider',
                'Tests\Fixtures\Modules\Beta\BetaServiceProvider',
                'Tests\Fixtures\Modules\Zeta\ZetaServiceProvider',
            ],
            ModuleProviderRegistry::discover($this->fixtures(), self::FIXTURE_NAMESPACE)
        );
    }

    public function test_a_discovered_provider_is_really_registered(): void
    {
        foreach (ModuleProviderRegistry::discover($this->fixtures(), self::FIXTURE_NAMESPACE) as $provider) {
            $this->app->register($provider);
        }

        // The container answering is the whole proof. Asserting the class list
        // again here would restate the previous test and demonstrate nothing.
        $this->assertSame('alpha', $this->app->make('module.alpha'));
        $this->assertSame('beta', $this->app->make('module.beta'));
        $this->assertSame('zeta', $this->app->make('module.zeta'));
    }

    public function test_providers_register_in_sorted_order(): void
    {
        foreach (ModuleProviderRegistry::discover($this->fixtures(), self::FIXTURE_NAMESPACE) as $provider) {
            $this->app->register($provider);
        }

        // End to end, but weak on its own: Alpha, Beta and Zeta are same-case and
        // differ at the first letter, so byte order, locale collation and raw
        // directory order all agree on them. What it does catch is a reversed or
        // shuffled implementation. The guarantee that actually matters is pinned
        // by the test below.
        $this->assertSame(['Alpha', 'Beta', 'Zeta'], RegistrationLog::$registered);
    }

    public function test_the_registration_order_is_the_same_on_every_platform(): void
    {
        // This cannot be tested through the filesystem, and that is why the
        // ordering is a function of its own.
        //
        // Sorting full paths puts the directory separator into the comparison.
        // On Linux `/` is 0x2F, below every letter, so `Auth/...` sorts before
        // `AuthExtra/...`. On Windows `\` is 0x5C, above every uppercase letter,
        // so the two swap. One module name being a prefix of another is all it
        // takes, and the suite runs only on Linux — the machine that would notice
        // is the developer host, where nobody runs it.
        //
        // So the order is taken over the segments, never over the joined path.
        $this->assertSame(
            [
                ['Auth', 'AuthServiceProvider'],
                ['AuthExtra', 'AuthExtraServiceProvider'],
                ['Catalog', 'CatalogEventServiceProvider'],
                ['Catalog', 'CatalogServiceProvider'],
            ],
            ModuleProviderRegistry::inRegistrationOrder([
                ['Catalog', 'CatalogServiceProvider'],
                ['AuthExtra', 'AuthExtraServiceProvider'],
                ['Catalog', 'CatalogEventServiceProvider'],
                ['Auth', 'AuthServiceProvider'],
            ])
        );
    }

    public function test_a_provider_below_its_module_directory_is_a_loud_failure(): void
    {
        // The registry looks one level down and no further. A provider tucked
        // into `Auth/Providers/` — the layout several Laravel packages use — would
        // otherwise be skipped in silence, and its module's bindings would simply
        // not exist. What surfaces then is a BindingResolutionException at request
        // time, nowhere near the cause.
        File::makeDirectory($this->temporaryRoot.'/Auth/Providers', 0755, true);
        File::put(
            $this->temporaryRoot.'/Auth/Providers/AuthServiceProvider.php',
            "<?php

namespace App\Modules\Auth\Providers;

class AuthServiceProvider {}
"
        );

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Auth'.DIRECTORY_SEPARATOR.'Providers');

        ModuleProviderRegistry::discover($this->temporaryRoot, 'App\Modules');
    }

    public function test_a_module_that_declares_no_provider_is_allowed(): void
    {
        // Not every module needs one. A module with routes and no bindings is
        // ordinary, and refusing it would make the registry harder to live with
        // than the shared file it replaces.
        File::makeDirectory($this->temporaryRoot.'/RoutesOnly', 0755, true);

        $this->assertSame([], ModuleProviderRegistry::discover($this->temporaryRoot, 'App\Modules'));
    }

    public function test_an_empty_module_directory_registers_nothing_and_raises_nothing(): void
    {
        // The state immediately after this task lands and before the first module
        // exists. A registry that treated it as a failure would stop the
        // application from booting at all.
        File::makeDirectory($this->temporaryRoot, 0755, true);

        $this->assertSame([], ModuleProviderRegistry::discover($this->temporaryRoot, 'App\\Modules'));
    }

    public function test_a_missing_module_directory_is_a_loud_failure(): void
    {
        // Silence here would mean every module's bindings had vanished with
        // nothing to say so, and the failures would surface one by one, far from
        // the cause.
        $missing = $this->temporaryRoot.'/never-created';

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($missing);

        ModuleProviderRegistry::discover($missing, 'App\\Modules');
    }

    public function test_a_provider_file_whose_class_does_not_match_psr4_is_a_loud_failure(): void
    {
        // The one mistake this layout invites: a file in the right place with the
        // wrong namespace. The autoloader would never find it, and without this
        // the module would simply be skipped and its bindings silently missing.
        File::makeDirectory($this->temporaryRoot.'/Ghost', 0755, true);
        File::put(
            $this->temporaryRoot.'/Ghost/GhostServiceProvider.php',
            "<?php\n\nnamespace Somewhere\\Else;\n\nclass GhostServiceProvider {}\n"
        );

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('App\\Modules\\Ghost\\GhostServiceProvider');

        ModuleProviderRegistry::discover($this->temporaryRoot, 'App\\Modules');
    }

    public function test_a_class_that_is_not_a_service_provider_is_a_loud_failure(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('BrokenServiceProvider');

        ModuleProviderRegistry::discover(
            $this->fixtures('ModulesWithNonProvider'),
            'Tests\\Fixtures\\ModulesWithNonProvider'
        );
    }

    public function test_the_application_provider_list_is_the_registry_and_nothing_else(): void
    {
        // This is what closes D-8. If a later task adds a provider to the shared
        // file by hand, this fails and says why — which is the only thing keeping
        // two concurrent tracks off one line of it.
        $this->assertSame(
            array_merge(
                [AppServiceProvider::class],
                ModuleProviderRegistry::discover(app_path('Modules'), 'App\\Modules')
            ),
            require base_path('bootstrap/providers.php'),
            'bootstrap/providers.php no longer consists of the framework provider plus whatever '
            .'the registry discovers. A provider added to it by hand is exactly the shared-file '
            .'edit D-8 exists to prevent.'
        );
    }
}
