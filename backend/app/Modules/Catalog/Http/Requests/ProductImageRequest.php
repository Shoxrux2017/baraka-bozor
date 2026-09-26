<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Catalog\ProductImages;
use Illuminate\Http\UploadedFile;

/**
 * The image upload of `docs/09` section 16: one file under `image`, at most
 * 5 MiB, JPEG, PNG or WebP judged by the bytes rather than by the file name
 * (`BR-CAT-004`), so a PDF renamed `.jpg` is refused.
 */
final class ProductImageRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'image' => [
                'bail', 'required', 'file',
                'mimetypes:'.implode(',', array_keys(ProductImages::EXTENSIONS)),
                'max:'.ProductImages::MAX_KILOBYTES,
            ],
        ];
    }

    public function uploadedImage(): UploadedFile
    {
        $file = $this->file('image');

        if (! $file instanceof UploadedFile) {
            // Unreachable after validation; stated for the type checker.
            abort(422);
        }

        return $file;
    }

    /**
     * The MIME type the bytes declare, which validation has already confined
     * to the three allowed.
     */
    public function mimeType(): string
    {
        return (string) $this->uploadedImage()->getMimeType();
    }
}
