<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\CustomerApproval;
use App\Models\Order;
use App\Models\OrderItem;
use App\Modules\Catalog\ProductImages;
use App\Modules\Orders\CourierContact;
use App\Modules\Orders\OrderLineSums;
use App\Modules\Orders\OrderRatings;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order in the Customer's list (`docs/09` section 20, `DL-42`): enough to
 * find it and see where it stands — the number, the status, the payment
 * method, how many lines, the total and its kind, when it was placed, the
 * street and house it goes to and a picture (`DL-91` (1)). The detail carries
 * the rest.
 *
 * Expects the sums of `OrderLineSums::add`, `picture_storage_key` of
 * `CustomerOrders::withPictureKey`, `preview_line_count` of
 * `CustomerOrders::withPreviewLineCount`, `openApprovals` (the question count
 * and the expiries come from the one read of it) and `previewItems`
 * with their products' pictures (`DL-131`) and `currentCourierAssignment.courier`
 * and `rating` loaded; the Courier's phone shows only while the order is on the way
 * (`DL-91` (2)).
 *
 * @property-read Order $resource
 */
final class CustomerOrderSummaryResource extends JsonResource
{
    public function __construct(Order $order)
    {
        parent::__construct($order);
    }

    public const PREVIEW_LINES = 4;

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $order = $this->resource;
        $totals = OrderLineSums::totals($order);

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'payment_method' => $order->payment_method->value,
            'item_count' => (int) $order->getAttribute('item_count'),
            'pending_approval_count' => $order->openApprovals->count(),
            'pending_approval_expires_at' => $order->openApprovals
                ->map(static fn (CustomerApproval $approval): string => $approval->expires_at->toIso8601ZuluString())
                ->values()
                ->all(),
            'total_uzs' => $totals->totalUzs,
            'total_kind' => $totals->kind,
            'address' => ['street' => $order->street_snapshot, 'house' => $order->house_snapshot],
            'courier_phone' => CourierContact::of($order)['phone'] ?? null,
            'image_url' => ProductImages::urlOfKey($order->getAttribute('picture_storage_key')),
            'preview' => $this->preview($order),
            'rating_stars' => $order->rating?->stars,
            'can_rate' => OrderRatings::canRate($order, now()),
            'created_at' => $order->created_at->toIso8601ZuluString(),
        ];
    }

    /**
     * The first lines of `Order::previewItems` and how many such lines the
     * order has (`DL-131` (2)): names from the lines' snapshots, the picture
     * the product has now.
     *
     * @return array{line_count: int, lines: list<array{name_uz: string, name_ru: string, image_url: string|null}>}
     */
    private function preview(Order $order): array
    {
        $count = (int) $order->getAttribute('preview_line_count');

        return [
            'line_count' => $count,
            'lines' => $order->previewItems
                ->take(min($count, self::PREVIEW_LINES))
                ->map(static fn (OrderItem $line): array => [
                    'name_uz' => $line->product_name_uz_snapshot,
                    'name_ru' => $line->product_name_ru_snapshot,
                    'image_url' => ProductImages::url($line->product?->image),
                ])
                ->values()
                ->all(),
        ];
    }
}
