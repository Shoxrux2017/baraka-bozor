<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Support\Idempotency\IdempotencyStore;
use Illuminate\Console\Command;

/**
 * Deletes the idempotency keys thirty days dead: completed more than thirty
 * days ago, or left `processing` by an attempt whose lease ran out more than
 * thirty days ago (`docs/08` section 27, `DL-104` (8)). A client retries within
 * minutes, so a key this old can never be replayed. Scheduled daily in
 * `routes/console.php`; running it again finds nothing more to do.
 */
final class PruneIdempotencyKeysCommand extends Command
{
    protected $signature = 'idempotency-keys:prune';

    protected $description = 'Delete idempotency keys that finished or died more than thirty days ago';

    public function handle(IdempotencyStore $store): int
    {
        $pruned = $store->prune(now()->subDays(30));

        $this->info("Pruned {$pruned} idempotency key(s).");

        return self::SUCCESS;
    }
}
