<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Log;

/**
 * How a failed query reaches the log (`AGENTS.md` section 5, `DL-25` (8)).
 *
 * PostgreSQL explains a refused row by quoting it: "Failing row contains
 * (…)" or "Key (phone)=(…) already exists" — a name, a phone, a password
 * hash. The query's own values are masked by the connection
 * (`mask_bindings_in_exception_messages`); this drops PostgreSQL's DETAIL,
 * HINT and CONTEXT lines as well, keeping what a developer needs — the
 * SQLSTATE, the violated constraint, the statement, where it failed and the
 * trace, whose argument values the container's PHP leaves out
 * (`zend.exception_ignore_args`).
 */
final class QueryFailureReport
{
    /**
     * Logs [$e] without the values and stops the framework's own report of
     * it, which would log the full message.
     */
    public static function report(QueryException $e): false
    {
        $previous = $e->getPrevious();

        Log::error('A database query failed.', [
            'error' => self::withoutDetail($previous?->getMessage() ?? $e->getMessage()),
            'sql' => $e->getSql(),
            'connection' => $e->getConnectionName(),
            'at' => $e->getFile().':'.$e->getLine(),
            'trace' => $e->getTraceAsString(),
        ]);

        return false;
    }

    /**
     * The driver's message up to PostgreSQL's first DETAIL, HINT or CONTEXT
     * line: `SQLSTATE[23514]: Check violation: 7 ERROR: new row for relation
     * "users" violates check constraint "users_phone_format_check"`.
     */
    public static function withoutDetail(string $message): string
    {
        return rtrim(preg_split('/\R\s*(?:DETAIL|HINT|CONTEXT):/', $message, 2)[0] ?? '');
    }
}
