<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use Carbon\CarbonInterface;
use InvalidArgumentException;

/**
 * The business's working hours in `Asia/Tashkent` (`BR-SET-001`, `docs/07`
 * section 26). Orders are accepted at any time; one placed outside the hours
 * is collected after opening, and checkout says so (`BR-CHK-009`,
 * `BR-AREA-002`).
 *
 * Open from `opens_at` up to, not including, `closes_at`. A closing time
 * before the opening time spans midnight (22:00–02:00). The settings refuse
 * equal times, so a business open round the clock enters 00:00–23:59, which
 * reads as always open (`DL-19` (8)).
 */
final readonly class WorkingHours
{
    public const ZONE = 'Asia/Tashkent';

    private const DAY_END = 23 * 60 + 59;

    private function __construct(
        private int $opens,
        private int $closes,
    ) {}

    /**
     * From two `HH:MM` or `HH:MM:SS` times, as the settings store them.
     */
    public static function of(string $opensAt, string $closesAt): self
    {
        return new self(self::minutes($opensAt), self::minutes($closesAt));
    }

    public function isAlwaysOpen(): bool
    {
        return $this->opens === 0 && $this->closes === self::DAY_END;
    }

    public function isOpenAt(CarbonInterface $instant): bool
    {
        if ($this->isAlwaysOpen()) {
            return true;
        }

        $local = $instant->copy()->setTimezone(self::ZONE);
        $minute = $local->hour * 60 + $local->minute;

        return $this->opens < $this->closes
            ? $minute >= $this->opens && $minute < $this->closes
            : $minute >= $this->opens || $minute < $this->closes;
    }

    /** `HH:MM`, for the client's "collected after opening at …". */
    public function opensAt(): string
    {
        return sprintf('%02d:%02d', intdiv($this->opens, 60), $this->opens % 60);
    }

    private static function minutes(string $time): int
    {
        if (preg_match('/^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\z/', $time, $parts) !== 1) {
            throw new InvalidArgumentException("\"{$time}\" is not a time of day.");
        }

        return (int) $parts[1] * 60 + (int) $parts[2];
    }
}
