<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Modules\Notifications\Actions\RevokePushDevice;
use Illuminate\Console\Command;

/**
 * Revokes the push devices not seen for sixty days, so a phone that was
 * dropped or sold stops receiving pushes. A device that was never seen counts
 * from its registration. Scheduled daily in `routes/console.php`; running it
 * again finds nothing more to do.
 */
final class PrunePushDevicesCommand extends Command
{
    protected $signature = 'push-devices:prune';

    protected $description = 'Revoke push devices unseen for sixty days';

    public function handle(): int
    {
        $revoked = RevokePushDevice::unseenSince(now()->subDays(60));

        $this->info("Revoked {$revoked} push device(s) unseen for 60 days.");

        return self::SUCCESS;
    }
}
