<?php

use App\Exceptions\ApiExceptionRenderer;
use App\Exceptions\QueryFailureReport;
use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\RejectMalformedInput;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull;
use Illuminate\Foundation\Http\Middleware\InvokeDeferredCallbacks;
use Illuminate\Foundation\Http\Middleware\PreventRequestsDuringMaintenance;
use Illuminate\Foundation\Http\Middleware\TrimStrings;
use Illuminate\Http\Middleware\HandleCors;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Middleware\ValidatePathEncoding;
use Illuminate\Http\Middleware\ValidatePostSize;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api/v1',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // First in the global stack, ahead of the framework's own global
        // middleware, so that their refusals carry the identifier too.
        $middleware->prepend(AssignRequestId::class);

        // The framework's default global stack, with the input check placed
        // after CORS, maintenance and the body-size check — so its `400` is
        // readable cross-origin and a too-large body stays a `413` — and
        // before the trimming (`DL-24`). The framework offers no "insert
        // before", so the stack is listed whole; `GlobalMiddlewareTest` fails
        // if it ever drifts from the framework's default.
        $middleware->use([
            ValidatePathEncoding::class,
            InvokeDeferredCallbacks::class,
            TrustProxies::class,
            HandleCors::class,
            PreventRequestsDuringMaintenance::class,
            ValidatePostSize::class,
            RejectMalformedInput::class,
            TrimStrings::class,
            ConvertEmptyStringsToNull::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => ApiExceptionRenderer::isApiRequest($request) || $request->expectsJson(),
        );

        $exceptions->render(
            fn (Throwable $e, Request $request) => ApiExceptionRenderer::render($e, $request),
        );

        // A failed query is logged without the row values PostgreSQL quotes.
        $exceptions->report(QueryFailureReport::report(...));
    })->create();
