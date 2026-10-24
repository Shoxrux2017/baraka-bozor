<?php

declare(strict_types=1);

namespace App\Modules\Notifications;

use App\Models\Enums\NotificationType;

final class NotificationText
{
    private const array LANGUAGES = ['uz', 'ru'];

    /**
     * @return array{title: string, body: string}
     */
    public function render(NotificationType $type, ?string $language, int $orderNumber, ?int $amountUzs): array
    {
        $locale = in_array($language, self::LANGUAGES, true) ? $language : 'uz';
        $replace = ['number' => (string) $orderNumber];

        if ($amountUzs !== null) {
            $replace['amount'] = $this->money($amountUzs, $locale);
        }

        return [
            'title' => trans('notifications.'.$type->value.'.title', $replace, $locale),
            'body' => trans('notifications.'.$type->value.'.body', $replace, $locale),
        ];
    }

    private function money(int $amountUzs, string $locale): string
    {
        $nbsp = mb_chr(0xA0);
        $currency = $locale === 'ru' ? 'сум' : "so'm";

        return number_format($amountUzs, 0, '', $nbsp).$nbsp.$currency;
    }
}
