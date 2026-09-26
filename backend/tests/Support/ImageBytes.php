<?php

declare(strict_types=1);

namespace Tests\Support;

use Illuminate\Http\UploadedFile;
use RuntimeException;

/**
 * Real one-pixel images in each allowed format, as uploaded files whose MIME
 * type is read from the bytes.
 *
 * Laravel's fake uploads report a MIME type guessed from the file name, so a
 * PDF named `photo.jpg` would pass as a JPEG and the upload rule would never
 * be exercised. These are genuine files on disk, handed over the way a real
 * request hands them over, so the type comes from `finfo` exactly as in
 * production. The container has no GD, so the images are the smallest valid
 * files of each kind rather than drawn ones.
 */
final class ImageBytes
{
    private const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

    private const JPEG = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

    private const WEBP = 'UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=';

    private const GIF = 'R0lGODlhAQABAAAAACwAAAAAAQABAAA=';

    /** @var list<string> */
    private static array $written = [];

    public static function png(string $name = 'pomidor.png'): UploadedFile
    {
        return self::file($name, self::decode(self::PNG));
    }

    public static function jpeg(string $name = 'pomidor.jpg'): UploadedFile
    {
        return self::file($name, self::decode(self::JPEG));
    }

    public static function webp(string $name = 'pomidor.webp'): UploadedFile
    {
        return self::file($name, self::decode(self::WEBP));
    }

    public static function gif(string $name = 'a.gif'): UploadedFile
    {
        return self::file($name, self::decode(self::GIF));
    }

    /**
     * A PDF under a JPEG name, whose client also claims `image/jpeg`: the name
     * and the header say image, the bytes do not.
     */
    public static function pdfNamedJpeg(): UploadedFile
    {
        return self::file('photo.jpg', "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n", 'image/jpeg');
    }

    /**
     * PNG bytes under a JPEG name: allowed, and stored by what the bytes are.
     */
    public static function pngNamedJpeg(): UploadedFile
    {
        return self::file('photo.jpg', self::decode(self::PNG), 'image/jpeg');
    }

    public static function svgNamedPng(): UploadedFile
    {
        return self::file('a.png', '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><rect width="1" height="1"/></svg>', 'image/png');
    }

    public static function htmlNamedPng(): UploadedFile
    {
        return self::file('a.png', "<!DOCTYPE html>\n<html><body><script>alert(1)</script></body></html>\n", 'image/png');
    }

    public static function emptyFile(): UploadedFile
    {
        return self::file('empty.png', '', 'image/png');
    }

    /**
     * Removes every file this class wrote, for a test's tearDown.
     */
    public static function cleanUp(): void
    {
        foreach (self::$written as $path) {
            if (is_file($path)) {
                unlink($path);
            }
        }

        self::$written = [];
    }

    /**
     * A PNG followed by padding to exactly [bytes] bytes, still detected as
     * a PNG, for the size limit.
     */
    public static function pngOfSize(int $bytes): UploadedFile
    {
        $png = self::decode(self::PNG);

        return self::file('big.png', $png.str_repeat("\0", max(0, $bytes - strlen($png))));
    }

    private static function file(string $name, string $contents, ?string $clientMimeType = null): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'bb-upload-');

        if ($path === false || file_put_contents($path, $contents) === false) {
            throw new RuntimeException('Could not write a temporary upload.');
        }

        self::$written[] = $path;

        return new UploadedFile($path, $name, $clientMimeType, null, true);
    }

    private static function decode(string $base64): string
    {
        $bytes = base64_decode($base64, true);

        if ($bytes === false) {
            throw new RuntimeException('Invalid fixture.');
        }

        return $bytes;
    }
}
