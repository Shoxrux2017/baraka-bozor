<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| One step of a concurrency test, in a process of its own
|--------------------------------------------------------------------------
|
| A test that must prove how two requests interleave cannot block and commit
| from one PHP process. It starts this script (`RunsInAnotherProcess`), which
| runs one named step against the test database, and prints the outcome as
| one JSON object on standard output: {"ok": true, ...} or {"ok": false,
| "error": "<class>", "code": "<api code>"}.
|
| It refuses to run against any database whose name does not end in `_test`.
|
*/

use App\Exceptions\ApiException;
use App\Models\User;
use App\Modules\Orders\Actions\AssignShopper;
use App\Modules\Orders\Actions\ChangeCart;
use App\Modules\Orders\Actions\CreateOrder;
use App\Modules\Orders\Actions\EditOrderItems;
use Illuminate\Contracts\Console\Kernel;

require __DIR__.'/../../../vendor/autoload.php';

$app = require __DIR__.'/../../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$database = (string) config('database.connections.pgsql.database');
if (! str_ends_with($database, '_test')) {
    fwrite(STDERR, "Refusing to run against {$database}.\n");
    exit(2);
}

$scenario = $argv[1] ?? '';
$arguments = array_slice($argv, 2);

try {
    $outcome = match ($scenario) {
        'cart.add' => [
            'cart_id' => (new ChangeCart)->add(
                User::query()->findOrFail($arguments[0]),
                ['product_id' => $arguments[1], 'quantity' => '1'],
            )->id,
        ],
        'orders.create' => [
            'order_id' => $app->make(CreateOrder::class)->create(
                User::query()->findOrFail($arguments[0]),
                $arguments[1],
                $arguments[2],
            )->id,
        ],
        'orders.assign-shopper' => [
            'order_id' => $app->make(AssignShopper::class)->assign(
                User::query()->findOrFail($arguments[0]),
                $arguments[1],
                $arguments[2],
            )->id,
        ],
        'orders.edit' => [
            'order_id' => $app->make(EditOrderItems::class)->edit(
                User::query()->findOrFail($arguments[0]),
                $arguments[1],
                [['product_id' => $arguments[2], 'quantity' => $arguments[3]]],
                null,
            )->id,
        ],
        default => throw new InvalidArgumentException("Unknown scenario {$scenario}."),
    };

    echo json_encode(['ok' => true] + $outcome, JSON_THROW_ON_ERROR);
} catch (Throwable $failure) {
    echo json_encode([
        'ok' => false,
        'error' => $failure::class,
        'code' => $failure instanceof ApiException ? $failure->apiCode() : null,
    ], JSON_THROW_ON_ERROR);
}
