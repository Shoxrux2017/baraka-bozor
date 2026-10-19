<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A login code gets a second purpose, `account_deletion` (`BR-ROLE-012`), and a
 * Customer account records when the person last accepted the terms and the
 * privacy policy at sign-in (`DL-94` item 3).
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->replacePurposeCheck(['customer_login', 'account_deletion']);

        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('terms_accepted_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('terms_accepted_at');
        });

        DB::table('customer_otp_challenges')->where('purpose', 'account_deletion')->delete();

        $this->replacePurposeCheck(['customer_login']);
    }

    /**
     * @param  list<string>  $purposes
     */
    private function replacePurposeCheck(array $purposes): void
    {
        $list = implode(', ', array_map(static fn (string $p): string => "'{$p}'", $purposes));

        DB::statement('alter table customer_otp_challenges drop constraint customer_otp_challenges_purpose_check');
        DB::statement("alter table customer_otp_challenges add constraint customer_otp_challenges_purpose_check check (purpose in ({$list}))");
    }
};
