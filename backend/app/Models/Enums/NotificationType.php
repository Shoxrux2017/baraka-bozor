<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The events that send a push (`05` Section 18, `DL-104` (10)), plus
 * `cancellation_rejected`, which the Owner added on 2026-10-24.
 */
enum NotificationType: string
{
    case OrderAccepted = 'order_accepted';
    case ShoppingAssigned = 'shopping_assigned';
    case ApprovalRequired = 'approval_required';
    case ApprovalAnswered = 'approval_answered';
    case ShoppingCompleted = 'shopping_completed';
    case PaymentRequired = 'payment_required';
    case CourierStarted = 'courier_started';
    case OrderDelivered = 'order_delivered';
    case OrderCancelled = 'order_cancelled';
    case ShoppingOrderCancelled = 'shopping_order_cancelled';
    case DeliveryAssigned = 'delivery_assigned';
    case DeliveryCancelled = 'delivery_cancelled';
    case CancellationRejected = 'cancellation_rejected';
}
