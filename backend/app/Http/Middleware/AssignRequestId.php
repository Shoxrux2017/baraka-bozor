<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Context;
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
 * Registered as the first global middleware. Route matching happens after
 * every global middleware whatever the order, so an unmatched route carries
 * the identifier regardless; being first additionally covers the framework's
 * own global middleware — malformed path encoding, maintenance mode, an
 * oversized body — whose refusals would otherwise get the renderer's fallback
 * identifier instead of one the logs also carry.
 */
final class AssignRequestId
{
    public const ATTRIBUTE = 'request_id';

    public function handle(Request $request, Closure $next): Response
    {
        $requestId = self::generate();

        $request->attributes->set(self::ATTRIBUTE, $requestId);

        // Context reaches every log line written during this request through
        // the framework's log processor, and it travels with any job the
        // request queues, so a job's log lines carry the request that queued it.
        Context::add(self::ATTRIBUTE, $requestId);

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
