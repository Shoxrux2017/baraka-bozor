<?php

declare(strict_types=1);

namespace Tests\Feature\Legal;

use App\Models\BusinessSettings;
use App\Models\Enums\LegalDocumentKind;
use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Legal\Actions\PublishLegalDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class LegalPagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_published_document_is_a_public_page(): void
    {
        Carbon::setTestNow('2026-10-19 20:30:00');
        $this->publish(LegalDocumentKind::Privacy, 'uz', "## Sarlavha\n<script>x</script>\n- Bir");

        $response = $this->get('/legal/privacy')->assertOk();

        $html = $response->getContent();
        $this->assertStringContainsString('<h2>Sarlavha</h2>', $html);
        $this->assertStringContainsString('&lt;script&gt;x&lt;/script&gt;', $html);
        $this->assertStringNotContainsString('<script>x', $html);
        $this->assertStringContainsString('<ul>', $html);
        $this->assertStringContainsString('<li>Bir</li>', $html);
        $this->assertStringContainsString('lang="uz"', $html);
        $this->assertStringContainsString('BarakaBozor', $html);
        $this->assertStringContainsString('Tahrir: 20.10.2026', $html);
        $this->assertStringContainsString('text/html; charset=utf-8', (string) $response->headers->get('Content-Type'));
        $this->assertStringContainsString('?lang=ru', $html);
    }

    public function test_the_language_falls_back_and_switches(): void
    {
        $this->publish(LegalDocumentKind::Terms, 'ru', "## Цены\nТекст");

        $this->get('/legal/terms?lang=uz')->assertOk()
            ->assertSee('lang="ru"', false)
            ->assertSee('<h2>Цены</h2>', false)
            ->assertSee('Редакция от', false);

        $this->get('/legal/terms?lang=de')->assertOk()->assertSee('lang="ru"', false);
    }

    public function test_an_unpublished_document_is_a_404_page(): void
    {
        $this->get('/legal/terms')->assertNotFound()
            ->assertSee(e("Hujjat hali e'lon qilinmagan."), false);

        $this->get('/legal/terms?lang=ru')->assertNotFound()
            ->assertSee('Документ ещё не опубликован.', false);
    }

    public function test_the_deletion_page_shows_the_support_phone_only_when_set(): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)
            ->update(['support_phone' => '+998712000000']);

        $this->get('/account-deletion?lang=ru')->assertOk()
            ->assertSee('+998 71 200 00 00', false)
            ->assertDontSee('+998712000000', false)
            ->assertSee('Удалим в течение 7 дней.', false)
            ->assertSee('Удаление аккаунта BarakaBozor', false)
            ->assertSee('/legal/privacy?lang=ru', false);

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)
            ->update(['support_phone' => null]);

        $this->get('/account-deletion?lang=ru')->assertOk()
            ->assertDontSee('+998 71 200 00 00', false)
            ->assertDontSee('Удалим в течение 7 дней.', false)
            ->assertSee('В приложении: Профиль', false);

        $this->get('/account-deletion')->assertOk()
            ->assertSee(e("BarakaBozor akkauntini o'chirish"), false)
            ->assertSee('lang="uz"', false);
    }

    public function test_pages_need_no_session_and_set_no_cookie(): void
    {
        $this->publish(LegalDocumentKind::Terms, 'uz', 'Matn');

        foreach (['/legal/terms', '/account-deletion', '/legal/privacy'] as $path) {
            $response = $this->get($path);

            $this->assertSame([], $response->headers->getCookies(), $path);
        }
    }

    private function publish(LegalDocumentKind $kind, string $language, string $body): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        app(PublishLegalDocument::class)->publish($admin, $kind, $language, $body);
    }
}
