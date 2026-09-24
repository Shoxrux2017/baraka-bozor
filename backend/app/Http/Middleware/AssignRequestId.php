<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gives every request one identifier that its log lines and its error
 * response share, so a user can quote it to support and support can find the
 * log — `docs/09-api-contracts.md` Section 3.
 *
 * The identifier is generated here, never taken from the client: an inbound
 * header would let a caller forge a value that looks like one of ours in the
 * logs. It is prefixed `req_` so it is recognisable wherever it appears, and
 * it is returned in error responses only; a successful response has no use
 * for it and no header carries it.
 *
 * Registered as global middleware, first in the stack, so a request that
 * matches no route — the most common API error — still has one.
 */
final class AssignRequestId
{
    public const ATTRIBUTE = 'request_id';

    public function handle(Request $request, Closure $next): Response
    {
        $requestId = self::generate();

        $request->attributes->set(self::ATTRIBUTE, $requestId);

        // Shared context reaches every log line written during this request,
        // by any channel, without each call site having to remember it.
        Log::shareContext([self::ATTRIBUTE => $requestId]);

        return $next($request);
    }

    /**
     * `req_` and a lowercase ULID: sortable by time, unguessable enough, and
     * safe in a URL or a log line.
     */
    public static function generate(): string
    {
        return 'req_'.Str::lower((string) Str::ulid());
    }
}
