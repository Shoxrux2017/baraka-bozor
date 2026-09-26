<?php

declare(strict_types=1);

namespace Tests\Unit\Staff;

use App\Modules\Staff\TemporaryPassword;
use PHPUnit\Framework\TestCase;

/**
 * `DL-17` (8): twelve characters from an alphabet without look-alikes.
 */
final class TemporaryPasswordTest extends TestCase
{
    public function test_the_alphabet_has_no_look_alikes_and_no_repeats(): void
    {
        foreach (['0', 'O', 'o', '1', 'I', 'l'] as $lookAlike) {
            $this->assertStringNotContainsString($lookAlike, TemporaryPassword::ALPHABET);
        }

        $this->assertSame(56, strlen(TemporaryPassword::ALPHABET));
        $this->assertSame(56, count(array_unique(str_split(TemporaryPassword::ALPHABET))));
    }

    public function test_a_password_is_twelve_characters_of_the_alphabet_and_each_is_new(): void
    {
        $seen = [];

        for ($i = 0; $i < 200; $i++) {
            $password = TemporaryPassword::generate();

            $this->assertSame(TemporaryPassword::LENGTH, strlen($password));
            $this->assertSame('', trim($password, TemporaryPassword::ALPHABET));
            $seen[$password] = true;
        }

        $this->assertCount(200, $seen);
    }
}
