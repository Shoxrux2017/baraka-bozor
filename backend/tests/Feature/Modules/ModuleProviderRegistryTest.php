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
        // Pinned against the implementation, not against the filesystem: byte
        // order is what `sort(SORT_STRING)` gives, and an implementation that
        // reversed it, left it to directory order, or sorted through the runtime
        // locale's collation would each produce a different list and fail here.
        // Route and binding precedence must not depend on which machine booted.
        foreach (ModuleProviderRegistry::discover($this->fixtures(), self::FIXTURE_NAMESPACE) as $provider) {
            $this->app->register($provider);
        }

        $this->assertSame(['Alpha', 'Beta', 'Zeta'], RegistrationLog::$registered);
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
