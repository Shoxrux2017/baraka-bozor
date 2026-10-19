<?php

declare(strict_types=1);

namespace Tests\Feature\Legal;

use App\Models\Enums\LegalDocumentKind;
use App\Models\Enums\Role;
use App\Models\LegalDocument;
use App\Models\User;
use App\Modules\Legal\Actions\PublishLegalDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

final class LegalDocumentsApiTest extends TestCase
{
    use RefreshDatabase;

    private const ADMIN_URL = '/api/v1/admin/legal-documents';

    public function test_an_admin_publishes_and_reads_documents(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();

        $list = $this->asAdmin($admin)->getJson(self::ADMIN_URL)->assertOk();
        $this->assertCount(4, $list->json('data'));
        $this->assertSame(
            ['terms-uz', 'terms-ru', 'privacy-uz', 'privacy-ru'],
            array_map(fn (array $e): string => $e['kind'].'-'.$e['language'], $list->json('data'))
        );
        foreach ($list->json('data') as $entry) {
            $this->assertNull($entry['body']);
            $this->assertNull($entry['updated_at']);
            $this->assertNull($entry['updated_by']);
        }

        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/ru', ['body' => "## A\nB"])
            ->assertOk()
            ->assertJsonPath('data.kind', 'terms')
            ->assertJsonPath('data.language', 'ru')
            ->assertJsonPath('data.body', "## A\nB")
            ->assertJsonPath('data.updated_by.id', $admin->id)
            ->assertJsonPath('data.updated_by.full_name', $admin->full_name)
            ->assertJsonStructure(['data' => ['updated_at']]);

        $entry = $this->asAdmin($admin)->getJson(self::ADMIN_URL)->json('data.1');
        $this->assertSame("## A\nB", $entry['body']);
        $this->assertNotNull($entry['updated_at']);
    }

    public function test_publishing_appends_and_repeats_naturally(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();

        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => 'Bir'])->assertOk();
        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => 'Ikki'])->assertOk();
        $this->assertSame(2, LegalDocument::query()->count());

        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => "Ikki\r\n"])
            ->assertOk()
            ->assertJsonPath('data.body', 'Ikki');
        $this->assertSame(2, LegalDocument::query()->count());

        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => '  '])
            ->assertOk()
            ->assertJsonPath('data.body', null);
        $this->assertSame(3, LegalDocument::query()->count());
        $this->getJson('/api/v1/legal/terms')->assertStatus(404);

        $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => null])->assertOk();
        $this->assertSame(3, LegalDocument::query()->count());
    }

    public function test_two_saves_at_the_same_instant_keep_their_order(): void
    {
        Carbon::setTestNow('2026-10-19 10:00:00');
        $admin = User::factory()->role(Role::Admin)->create();

        foreach (['Bir', 'Ikki', 'Uch', 'To\'rt'] as $body) {
            $this->asAdmin($admin)->putJson(self::ADMIN_URL.'/terms/ru', ['body' => $body])->assertOk();
        }

        $this->assertSame(4, LegalDocument::query()->count());
        $this->assertSame('To\'rt', $this->asAdmin($admin)->getJson(self::ADMIN_URL)->json('data.1.body'));
        $this->getJson('/api/v1/legal/terms?language=ru')->assertOk()
            ->assertJsonPath('data.blocks.0.text', 'To\'rt');
    }

    public function test_the_public_api_answers_blocks_with_a_language_fallback(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        app(PublishLegalDocument::class)->publish($admin, LegalDocumentKind::Terms, 'ru', "## Цены\nТекст");

        foreach (['ru', 'uz'] as $language) {
            $this->getJson('/api/v1/legal/terms?language='.$language)
                ->assertOk()
                ->assertJsonPath('data.kind', 'terms')
                ->assertJsonPath('data.language', 'ru')
                ->assertJsonPath('data.blocks', [
                    ['type' => 'heading', 'text' => 'Цены'],
                    ['type' => 'paragraph', 'text' => 'Текст'],
                ])
                ->assertJsonStructure(['data' => ['updated_at']]);
        }

        $this->getJson('/api/v1/legal?language=uz')
            ->assertOk()
            ->assertJsonPath('data.terms.language', 'ru')
            ->assertJsonStructure(['data' => ['terms' => ['language', 'updated_at']]])
            ->assertJsonPath('data.privacy', null);

        $this->getJson('/api/v1/legal/privacy')->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        $this->getJson('/api/v1/legal/other')->assertStatus(404);
        $this->getJson('/api/v1/legal/terms?language=en')->assertStatus(422);
        $this->getJson('/api/v1/legal?language=en')->assertStatus(422);
    }

    public function test_the_document_text_is_never_html(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        app(PublishLegalDocument::class)->publish($admin, LegalDocumentKind::Privacy, 'uz', '<script>x</script>');

        $this->getJson('/api/v1/legal/privacy')
            ->assertOk()
            ->assertJsonPath('data.blocks.0.text', '<script>x</script>');
    }

    public function test_only_admins_edit(): void
    {
        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Operator, Role::Manager] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            $this->withToken($token)->getJson(self::ADMIN_URL)->assertStatus(403);
            $this->withToken($token)->putJson(self::ADMIN_URL.'/terms/uz', ['body' => 'x'])->assertStatus(403);
        }
        $this->assertSame(0, LegalDocument::query()->count());

        $this->asAdmin()->putJson(self::ADMIN_URL.'/other/uz', ['body' => 'x'])->assertStatus(404);
        $this->asAdmin()->putJson(self::ADMIN_URL.'/terms/en', ['body' => 'x'])->assertStatus(404);

        foreach ([
            ['body' => str_repeat('a', 50001)],
            [],
            ['body' => 'x', 'extra' => 1],
            ['body' => 5],
        ] as $body) {
            $this->asAdmin()->putJson(self::ADMIN_URL.'/terms/uz', $body)
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed');
        }
        $this->assertSame(0, LegalDocument::query()->count());
    }

    private function asAdmin(?User $admin = null): self
    {
        $admin ??= User::factory()->role(Role::Admin)->create();

        return $this->withToken($admin->createToken('t')->plainTextToken);
    }
}
