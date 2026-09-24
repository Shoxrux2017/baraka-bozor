<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `customer_otp_challenges.channel`, per `docs/08-database.md` Section 4: which
 * way the code left — Telegram, SMS, the development fake, or not at all for
 * a configured test phone. Recorded for support and for the hourly send
 * counters; it says nothing about the code itself.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_otp_challenges', function (Blueprint $table): void {
            $table->string('channel', 16);
        });

        DB::statement(
            "alter table customer_otp_challenges add constraint customer_otp_challenges_channel_check check (channel in ('telegram', 'sms', 'fake', 'test'))"
        );
    }

    public function down(): void
    {
        DB::statement('alter table customer_otp_challenges drop constraint customer_otp_challenges_channel_check');

        Schema::table('customer_otp_challenges', function (Blueprint $table): void {
            $table->dropColumn('channel');
        });
    }
};
