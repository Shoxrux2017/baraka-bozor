<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The nine order states of `DL-4` and `05` Section 9. Explicit actions own
 * every transition (`BR-ORDER-002`).
 */
enum OrderStatus: string
{
    case New = 'new';
    case ShoppingAssigned = 'shopping_assigned';
    case Shopping = 'shopping';
    case FinalPaymentPending = 'final_payment_pending';
    case ReadyForDelivery = 'ready_for_delivery';
    case DeliveryAssigned = 'delivery_assigned';
    case OnTheWay = 'on_the_way';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
}
