<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

/**
 * `400 malformed_request` for input no client should ever send
 * (`docs/09-api-contracts.md` section 3, `DL-24`):
 *
 * - a JSON body the decoder cannot read. Laravel would hand it to the
 *   application as an empty input bag, so a truncated body would be judged as
 *   one that sent nothing: a `422` on missing fields at best, a silent no-op
 *   where every field is optional;
 * - text that is not UTF-8 or holds a NUL byte, in the query string, the body
 *   or an uploaded file's name, keys included. PostgreSQL refuses the first
 *   with an error that would surface as `500`, and the database driver cuts
 *   the second at the NUL and would store half a value.
 *
 * It runs in the global stack after CORS, maintenance and the body-size
 * check, so its refusal is readable by the web panel and a too-large body is
 * still a `413`; and before the trimming, so it judges the input as sent
 * rather than after NULs at either end were trimmed away. The URL path is
 * checked by the framework's own `ValidatePathEncoding`, earlier still.
 *
 * The refusal is a plain HTTP `400`: the API renderer turns it into the
 * envelope, and anywhere else the framework renders it as it renders any
 * `400`.
 */
final class RejectMalformedInput
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isJson()) {
            $body = $request->getContent();

            if (trim($body) !== '' && ! json_validate($body)) {
                throw new BadRequestHttpException;
            }
        }

        // For a JSON request, `request` is the decoded body.
        if (! self::isClean($request->query->all())
            || ! self::isClean($request->request->all())
            || ! self::isClean(self::fileNames($request->allFiles()))) {
            throw new BadRequestHttpException;
        }

        return $next($request);
    }

    /**
     * @param  array<array-key, mixed>  $input
     */
    private static function isClean(array $input): bool
    {
        foreach ($input as $key => $value) {
            if (is_string($key) && ! self::isCleanText($key)) {
                return false;
            }

            if (is_array($value) ? ! self::isClean($value) : (is_string($value) && ! self::isCleanText($value))) {
                return false;
            }
        }

        return true;
    }

    private static function isCleanText(string $text): bool
    {
        return ! str_contains($text, "\0") && mb_check_encoding($text, 'UTF-8');
    }

    /**
     * The client's names of the uploaded files, keyed like the files.
     *
     * @param  array<array-key, mixed>  $files
     * @return array<array-key, mixed>
     */
    private static function fileNames(array $files): array
    {
        $names = [];

        foreach ($files as $key => $file) {
            $names[$key] = match (true) {
                $file instanceof UploadedFile => $file->getClientOriginalName(),
                is_array($file) => self::fileNames($file),
                default => null,
            };
        }

        return $names;
    }
}
