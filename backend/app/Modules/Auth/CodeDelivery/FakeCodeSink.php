<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

/**
 * Where the fake gateway puts the codes it "delivers": an in-process store
 * that only a test in the same process can read. It is bound as a singleton,
 * lives for one process, and is never written to a log, a file, a response or
 * a header — the rule of `AGENTS.md` Section 5 has no development exception.
 */
final class FakeCodeSink
{
    /** @var array<string, string> phone => the last code delivered to it */
    private array $codes = [];

    public function record(string $phone, #[\SensitiveParameter] string $code): void
    {
        $this->codes[$phone] = $code;
    }

    public function codeFor(string $phone): ?string
    {
        return $this->codes[$phone] ?? null;
    }
}
