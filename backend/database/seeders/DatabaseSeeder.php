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
     * Nothing is seeded at this Stage. There is no BarakaBozor business table
     * yet, and the initial Admin is created by a controlled one-time CLI
     * bootstrap in S01-BE-002, never by a seeder.
     */
    public function run(): void
    {
        //
    }
}
