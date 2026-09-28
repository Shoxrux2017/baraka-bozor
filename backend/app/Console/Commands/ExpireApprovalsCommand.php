<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Modules\Orders\ApprovalExpiry;
use Illuminate\Console\Command;

/**
 * Writes the expiry of every approval past its thirty minutes (`BR-APP-003`,
 * `DL-54` (8), `DL-60`), one order at a time under its lock, each expiry with
 * its one `approval_expired` history row. Scheduled every minute in
 * `routes/console.php`; running it again finds nothing more to do.
 *
 * Correctness never waits for it: every read shows an overdue approval as
 * expired, and every action expires the order's own first (`docs/07`
 * section 25).
 */
final class ExpireApprovalsCommand extends Command
{
    protected $signature = 'approvals:expire';

    protected $description = 'Expire the approvals the Customer did not answer within thirty minutes';

    public function handle(): int
    {
        $orders = CustomerApproval::query()
            ->where('status', ApprovalStatus::Pending->value)
            ->where('expires_at', '<=', now())
            ->distinct()
            ->pluck('order_id');

        $expired = 0;
        foreach ($orders as $orderId) {
            $expired += ApprovalExpiry::expireOverdueOf((string) $orderId);
        }

        $this->info("Expired {$expired} approval(s).");

        return self::SUCCESS;
    }
}
