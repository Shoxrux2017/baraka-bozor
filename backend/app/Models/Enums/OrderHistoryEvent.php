<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The `order_history.event_type` vocabulary of `08` Section 15, with the
 * events of Wave 3's actions (`DL-54` (2)).
 */
enum OrderHistoryEvent: string
{
    case StatusChanged = 'status_changed';
    case Edited = 'edited';
    case PaymentMethodSwitched = 'payment_method_switched';
    case PriceCorrected = 'price_corrected';
    case ShopperAssigned = 'shopper_assigned';
    case ShopperReassigned = 'shopper_reassigned';
    case CourierAssigned = 'courier_assigned';
    case CourierReassigned = 'courier_reassigned';
    case DeliveryFailed = 'delivery_failed';
    case ApprovalRequested = 'approval_requested';
    case ApprovalDecided = 'approval_decided';
    case ApprovalExpired = 'approval_expired';
    case ApprovalResolved = 'approval_resolved';
    case ShopperAccepted = 'shopper_accepted';
    case CourierAccepted = 'courier_accepted';
    case ItemPurchased = 'item_purchased';
    case ItemUnavailable = 'item_unavailable';
    case ItemSubstituted = 'item_substituted';
    case CancellationRequested = 'cancellation_requested';
    case CancellationRequestDecided = 'cancellation_request_decided';
    case PaymentRecorded = 'payment_recorded';
}
