<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\NotificationDelivery;
use Illuminate\Console\Command;

/**
 * Deletes the notification delivery records kept more than ninety days
 * (`docs/08` section 26, `DL-112`). Scheduled daily in `routes/console.php`;
 * running it again finds nothing more to do.
 */
final class PruneNotificationDeliveriesCommand extends Command
{
    protected $signature = 'notification-deliveries:prune';

    protected $description = 'Delete notification delivery records created more than ninety days ago';

    public function handle(): int
    {
        $pruned = NotificationDelivery::query()->where('created_at', '<', now()->subDays(90))->delete();

        $this->info("Pruned {$pruned} notification delivery record(s).");

        return self::SUCCESS;
    }
}
