<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Modules\Settings\WorkingHours;
use Carbon\CarbonInterface;

/**
 * The summary strip above the board (`docs/09` section 38, `DL-37` (16),
 * interview 9.2), for the day in `Asia/Tashkent`:
 *
 * - every open order by its current status, whatever day it was placed — an
 *   order placed overnight is collected in the morning (`BR-CHK-009`);
 * - today's completed and cancelled orders, by `completed_at` and
 *   `cancelled_at` (`docs/05` section 20);
 * - today's sales, the sum of `final_total_uzs` of the orders completed today;
 * - the number of attention items.
 */
final readonly class BoardSummary
{
    /**
     * @param  array<string, int>  $openByStatus
     */
    private function __construct(
        public string $day,
        public array $openByStatus,
        public int $completedToday,
        public int $cancelledToday,
        public int $salesTodayUzs,
        public int $attentionCount,
    ) {}

    public static function at(CarbonInterface $now): self
    {
        $local = $now->copy()->setTimezone(WorkingHours::ZONE);
        $start = $local->copy()->startOfDay()->utc();
        $end = $local->copy()->startOfDay()->addDay()->utc();

        $open = [];
        foreach (OrderBoard::OPEN as $status) {
            $open[$status->value] = 0;
        }
        $counts = Order::query()
            ->whereIn('status', array_keys($open))
            ->selectRaw('status, count(*) as orders')
            ->groupBy('status')
            ->toBase()
            ->get();
        foreach ($counts as $row) {
            $open[(string) $row->status] = (int) $row->orders;
        }

        $completed = Order::query()
            ->where('status', OrderStatus::Completed->value)
            ->where('completed_at', '>=', $start)
            ->where('completed_at', '<', $end);

        return new self(
            $local->toDateString(),
            $open,
            (clone $completed)->count(),
            Order::query()->where('status', OrderStatus::Cancelled->value)
                ->where('cancelled_at', '>=', $start)
                ->where('cancelled_at', '<', $end)
                ->count(),
            (int) (clone $completed)->sum('final_total_uzs'),
            Attention::selfOrders(Order::query())->count(),
        );
    }
}
