<?php

declare(strict_types=1);

$handoffPoint = env('DELIVERY_HANDOFF_POINT');

return [

    /*
    |--------------------------------------------------------------------------
    | The handoff point
    |--------------------------------------------------------------------------
    |
    | Whether the Courier collects each order at the business's handoff point
    | (BR-DEL-006, interview 1.1, option A). While the business runs without
    | one, the Courier's order carries the phone of the Shopper who bought it,
    | so the two can meet at the market (DL-54 (11)).
    |
    | Only an explicit false value — false, 0, no, off — turns it off. Unset,
    | empty or unreadable, it stays on, so a missing setting never shows the
    | Courier a Shopper's phone (DL-63 (3)).
    |
    */

    'handoff_point' => $handoffPoint === null || $handoffPoint === ''
        || filter_var($handoffPoint, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) !== false,

];
