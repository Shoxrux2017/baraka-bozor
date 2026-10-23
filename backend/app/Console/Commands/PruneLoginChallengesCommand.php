<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Modules\Auth\Models\LoginChallenge;
use Illuminate\Console\Command;

/**
 * Deletes the login challenges created more than thirty days ago (`DL-104`
 * (8)). A challenge lives minutes; the old ones only keep the phone numbers of
 * people who never became Customers. Scheduled daily in `routes/console.php`;
 * running it again finds nothing more to do.
 */
final class PruneLoginChallengesCommand extends Command
{
    protected $signature = 'login-challenges:prune';

    protected $description = 'Delete login challenges created more than thirty days ago';

    public function handle(): int
    {
        $pruned = LoginChallenge::query()
            ->where('created_at', '<', now()->subDays(30))
            ->delete();

        $this->info("Pruned {$pruned} login challenge(s).");

        return self::SUCCESS;
    }
}
