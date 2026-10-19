<?php

declare(strict_types=1);

namespace Tests\Unit\Legal;

use App\Modules\Legal\LegalText;
use PHPUnit\Framework\TestCase;

final class LegalTextTest extends TestCase
{
    public function test_blocks(): void
    {
        $this->assertSame([
            ['type' => 'heading', 'text' => 'Цены'],
            ['type' => 'paragraph', 'text' => 'Цены примерные.'],
            ['type' => 'item', 'text' => 'Один'],
            ['type' => 'item', 'text' => 'Два'],
            ['type' => 'paragraph', 'text' => 'Конец'],
        ], LegalText::blocks("## Цены\nЦены примерные.\n\n- Один\n- Два\r\nКонец"));
    }

    public function test_lines_are_trimmed_and_empty_markers_dropped(): void
    {
        $this->assertSame([
            ['type' => 'paragraph', 'text' => 'Текст'],
        ], LegalText::blocks("   Текст  \n\n##\n- \n   \n"));
    }

    public function test_markup_stays_literal_text(): void
    {
        $this->assertSame(
            [['type' => 'paragraph', 'text' => '<script>x</script>']],
            LegalText::blocks('<script>x</script>')
        );
    }
}
