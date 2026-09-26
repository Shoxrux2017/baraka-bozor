<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\RejectMalformedInput;
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Foundation\Http\Kernel as HttpKernel;
use Illuminate\Foundation\Http\Middleware\TrimStrings;
use Tests\TestCase;

/**
 * `bootstrap/app.php` lists the global stack whole to place the input check
 * (`DL-24`). This pins it to the framework's own default, so an upgrade that
 * adds, removes or reorders a default global middleware fails here instead of
 * silently losing it.
 */
final class GlobalMiddlewareTest extends TestCase
{
    public function test_the_stack_is_the_framework_default_with_the_request_id_first_and_the_input_check_before_the_trimming(): void
    {
        $default = (new Middleware)->getGlobalMiddleware();
        $trimming = array_search(TrimStrings::class, $default, true);
        $this->assertIsInt($trimming);

        $expected = [
            AssignRequestId::class,
            ...array_slice($default, 0, $trimming),
            RejectMalformedInput::class,
            ...array_slice($default, $trimming),
        ];

        $kernel = $this->app->make(Kernel::class);
        $this->assertInstanceOf(HttpKernel::class, $kernel);
        $this->assertSame($expected, $kernel->getGlobalMiddleware());
    }
}
