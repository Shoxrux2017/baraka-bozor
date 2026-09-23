<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * Nothing is seeded here, and the first Admin in particular is not. It is
     * created by `bootstrap:first-admin`, a controlled one-time CLI — BR-ROLE-009
     * — never by a seeder and never by a public API. A seeder runs unattended and
     * would have to carry a password in the repository to do it.
     */
    public function run(): void
    {
        //
    }
}
