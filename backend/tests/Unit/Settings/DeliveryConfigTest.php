<?php

declare(strict_types=1);

namespace Tests\Unit\Settings;

use PHPUnit\Framework\TestCase;

/**
 * How `config/delivery.php` reads `DELIVERY_HANDOFF_POINT` (`BR-DEL-006`,
 * `DL-63` (3)): only an explicit false value turns the handoff point off, so a
 * missing or mistyped setting never shows a Courier a Shopper's phone.
 */
final class DeliveryConfigTest extends TestCase
{
    private const NAME = 'DELIVERY_HANDOFF_POINT';

    public function test_only_an_explicit_false_value_turns_the_handoff_point_off(): void
    {
        foreach ([
            ['false', false],
            ['FALSE', false],
            ['0', false],
            ['no', false],
            ['off', false],
            ['true', true],
            ['1', true],
            ['yes', true],
            ['', true],
            ['maybe', true],
            [null, true],
        ] as [$value, $expected]) {
            $this->assertSame($expected, $this->handoffPointWith($value), var_export($value, true));
        }
    }

    private function handoffPointWith(?string $value): bool
    {
        $saved = [$_SERVER[self::NAME] ?? null, $_ENV[self::NAME] ?? null, getenv(self::NAME)];

        try {
            if ($value === null) {
                unset($_SERVER[self::NAME], $_ENV[self::NAME]);
                putenv(self::NAME);
            } else {
                $_SERVER[self::NAME] = $_ENV[self::NAME] = $value;
                putenv(self::NAME.'='.$value);
            }

            /** @var array{handoff_point: bool} $config */
            $config = require __DIR__.'/../../../config/delivery.php';

            return $config['handoff_point'];
        } finally {
            [$server, $env, $process] = $saved;
            unset($_SERVER[self::NAME], $_ENV[self::NAME]);
            if ($server !== null) {
                $_SERVER[self::NAME] = $server;
            }
            if ($env !== null) {
                $_ENV[self::NAME] = $env;
            }
            putenv($process === false ? self::NAME : self::NAME.'='.$process);
        }
    }
}
