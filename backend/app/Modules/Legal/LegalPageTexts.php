<?php

declare(strict_types=1);

namespace App\Modules\Legal;

use App\Models\Enums\LegalDocumentKind;

/**
 * The fixed texts of the public pages (`DL-94` item 2), per language. The
 * documents themselves come from the Admin; these describe the product.
 */
final class LegalPageTexts
{
    public const DEFAULT_LANGUAGE = 'uz';

    public static function language(mixed $asked): string
    {
        return in_array($asked, LegalDocuments::LANGUAGES, true) ? $asked : self::DEFAULT_LANGUAGE;
    }

    public static function otherLanguage(string $language): string
    {
        return $language === 'uz' ? 'ru' : 'uz';
    }

    public static function languageName(string $language): string
    {
        return $language === 'uz' ? "O'zbekcha" : 'Русский';
    }

    public static function documentTitle(LegalDocumentKind $kind, string $language): string
    {
        return match ($kind) {
            LegalDocumentKind::Terms => $language === 'ru' ? 'Условия использования' : 'Foydalanish shartlari',
            LegalDocumentKind::Privacy => $language === 'ru' ? 'Политика конфиденциальности' : 'Maxfiylik siyosati',
        };
    }

    public static function edition(string $language): string
    {
        return $language === 'ru' ? 'Редакция от' : 'Tahrir:';
    }

    /** `+998712000000` is shown as `+998 71 200 00 00`; any other shape is shown as stored. */
    private static function readablePhone(string $phone): string
    {
        return preg_replace('/^(\+998)(\d{2})(\d{3})(\d{2})(\d{2})$/', '$1 $2 $3 $4 $5', $phone) ?? $phone;
    }

    public static function notPublished(string $language): string
    {
        return $language === 'ru' ? 'Документ ещё не опубликован.' : "Hujjat hali e'lon qilinmagan.";
    }

    /**
     * @return array{
     *     title: string, inApp: string, byPhone: string, erased: string, kept: string,
     *     unfinished: string, privacy: string
     * }
     */
    public static function deletion(string $language, ?string $supportPhone): array
    {
        $supportPhone = $supportPhone === null ? null : self::readablePhone($supportPhone);

        if ($language === 'ru') {
            return [
                'title' => 'Удаление аккаунта BarakaBozor',
                'inApp' => 'В приложении: Профиль → «Удалить аккаунт», подтвердите кодом.',
                'byPhone' => $supportPhone === null ? '' : "Без приложения: позвоните в поддержку {$supportPhone} с номера, на который открыт аккаунт. Удалим в течение 7 дней.",
                'erased' => 'Что сотрём: имя, номер телефона, адреса, избранное и корзину.',
                'kept' => 'Что останется: история заказов — без имени и телефона, для учёта.',
                'unfinished' => 'Если есть незавершённый заказ, удалить аккаунт можно после его доставки или отмены.',
                'privacy' => self::documentTitle(LegalDocumentKind::Privacy, 'ru'),
            ];
        }

        return [
            'title' => "BarakaBozor akkauntini o'chirish",
            'inApp' => "Ilovada: Profil → «Akkauntni o'chirish», kod bilan tasdiqlang.",
            'byPhone' => $supportPhone === null ? '' : "Ilovasiz: akkaunt ochilgan raqamdan {$supportPhone} qo'llab-quvvatlash raqamiga qo'ng'iroq qiling. 7 kun ichida o'chiramiz.",
            'erased' => "Nimalar o'chiriladi: ism, telefon raqami, manzillar, sevimlilar va savat.",
            'kept' => 'Nima qoladi: buyurtmalar tarixi — ism va telefonsiz, hisob uchun.',
            'unfinished' => "Tugallanmagan buyurtma bo'lsa, akkauntni u yetkazilgan yoki bekor qilingandan keyin o'chirish mumkin.",
            'privacy' => self::documentTitle(LegalDocumentKind::Privacy, 'uz'),
        ];
    }
}
