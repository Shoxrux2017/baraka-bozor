<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Modules\Orders\ApprovalExpiry;
use Illuminate\Console\Command;
use Throwable;

/**
 * Writes the expiry of every approval past its thirty minutes (`BR-APP-003`,
 * `DL-54` (8), `DL-60`), one order at a time under its lock, each expiry with
 * its one `approval_expired` history row. Scheduled every minute in
 * `routes/console.php`; running it again finds nothing more to do.
 *
 * Correctness never waits for it: every read shows an overdue approval as
 * expired, and the Shopper's line actions, the Customer's decision and the
 * Operator's removal expire the order's own first (`docs/07` section 25,
 * `DL-60` (1)). An order that fails is reported and leaves the others to
 * run; the run then fails, and the next one tries that order again.
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
        $failed = 0;
        foreach ($orders as $orderId) {
            try {
                $expired += ApprovalExpiry::expireOverdueOf((string) $orderId);
            } catch (Throwable $failure) {
                report($failure);
                $failed++;
            }
        }

        $this->info("Expired {$expired} approval(s).");
        if ($failed > 0) {
            $this->error("{$failed} order(s) failed.");

            return self::FAILURE;
        }

        return self::SUCCESS;
    }
}
