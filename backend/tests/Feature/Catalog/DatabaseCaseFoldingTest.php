<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Catalog search lets PostgreSQL lowercase names (`DL-20` (3)). Under a
 * `C` or `POSIX` character type `lower()` folds ASCII only, and Cyrillic
 * search would silently turn case-sensitive; this fails first
 * (`docs/08` section 1).
 */
final class DatabaseCaseFoldingTest extends TestCase
{
    public function test_the_database_folds_cyrillic_and_latin_case(): void
    {
        $this->assertSame('ёлка помидор o\'rik', DB::scalar("select lower('ЁЛКА ПОМИДОР O''RIK')"));
    }
}
