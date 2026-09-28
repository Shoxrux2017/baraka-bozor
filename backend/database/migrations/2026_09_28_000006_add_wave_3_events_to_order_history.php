<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * The events Wave 3's actions write besides status changes (`DL-54` (2),
 * `docs/08-database.md` Section 15), so the history explains every action
 * (`docs/05` Section 22). A forward change of the check, not an edit of the
 * Wave 2 migration: that one has run where the table holds rows.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const WAVE_2 = [
        'status_changed', 'edited', 'payment_method_switched', 'price_corrected',
        'shopper_assigned', 'shopper_reassigned', 'courier_assigned', 'courier_reassigned',
        'delivery_failed', 'approval_requested', 'approval_decided', 'approval_expired', 'approval_resolved',
    ];

    /** @var list<string> */
    private const WAVE_3 = [
        'shopper_accepted', 'courier_accepted', 'item_purchased', 'item_unavailable', 'item_substituted',
        'cancellation_requested', 'cancellation_request_decided', 'payment_recorded',
    ];

    public function up(): void
    {
        $this->replaceCheck([...self::WAVE_2, ...self::WAVE_3]);
    }

    public function down(): void
    {
        $this->replaceCheck(self::WAVE_2);
    }

    /**
     * @param  list<string>  $events
     */
    private function replaceCheck(array $events): void
    {
        $quoted = implode(', ', array_map(static fn (string $event): string => "'{$event}'", $events));

        DB::statement('alter table order_history drop constraint order_history_event_type_check');
        DB::statement("alter table order_history add constraint order_history_event_type_check check (event_type in ({$quoted}))");
    }
};
