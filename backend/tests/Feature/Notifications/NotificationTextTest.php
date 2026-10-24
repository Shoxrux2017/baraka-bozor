<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\Enums\NotificationType;
use App\Modules\Notifications\NotificationText;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

final class NotificationTextTest extends TestCase
{
    /**
     * @return iterable<string, array{NotificationType, string}>
     */
    public static function typesAndLanguages(): iterable
    {
        foreach (NotificationType::cases() as $type) {
            foreach (['uz', 'ru'] as $language) {
                yield $type->value.' '.$language => [$type, $language];
            }
        }
    }

    #[DataProvider('typesAndLanguages')]
    public function test_every_type_renders_in_both_languages(NotificationType $type, string $language): void
    {
        $text = (new NotificationText)->render($type, $language, 1001, 251250);

        $this->assertNotSame('', $text['title']);
        $this->assertNotSame('', $text['body']);
        $this->assertStringNotContainsString('notifications.', $text['title']);
        $this->assertStringNotContainsString('notifications.', $text['body']);
        $this->assertStringContainsString('№1001', $text['body']);
        $this->assertDoesNotMatchRegularExpression('/:[a-z]/', $text['title']);
        $this->assertDoesNotMatchRegularExpression('/:[a-z]/', $text['body']);
    }

    public function test_the_amount_is_grouped_with_no_break_spaces_and_the_currency(): void
    {
        $nbsp = mb_chr(0xA0);
        $service = new NotificationText;

        $uz = $service->render(NotificationType::ShoppingCompleted, 'uz', 1001, 251250);
        $ru = $service->render(NotificationType::ShoppingCompleted, 'ru', 1001, 251250);

        $this->assertStringContainsString('251'.$nbsp.'250'.$nbsp."so'm", $uz['body']);
        $this->assertStringContainsString('251'.$nbsp.'250'.$nbsp.'сум', $ru['body']);
    }

    public function test_an_unknown_or_missing_language_renders_uzbek(): void
    {
        $service = new NotificationText;

        $this->assertSame('Buyurtma qabul qilindi', $service->render(NotificationType::OrderAccepted, 'en', 1001, null)['title']);
        $this->assertSame('Buyurtma qabul qilindi', $service->render(NotificationType::OrderAccepted, null, 1001, null)['title']);
    }

    public function test_the_two_files_hold_the_same_keys_and_only_the_two_placeholders(): void
    {
        $expected = array_map(static fn (NotificationType $type): string => $type->value, NotificationType::cases());

        foreach (['uz', 'ru'] as $language) {
            $texts = require lang_path($language.'/notifications.php');

            $keys = array_keys($texts);
            sort($keys);
            $sorted = $expected;
            sort($sorted);
            $this->assertSame($sorted, $keys, $language);

            foreach ($texts as $type => $entry) {
                $this->assertSame(['body', 'title'], collect(array_keys($entry))->sort()->values()->all(), "$language $type");
                foreach ($entry as $value) {
                    preg_match_all('/:([A-Za-z_]+)/', $value, $matches);
                    foreach ($matches[1] as $placeholder) {
                        $this->assertContains($placeholder, ['number', 'amount'], "$language $type");
                    }
                }
            }
        }
    }
}
