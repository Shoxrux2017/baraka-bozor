<?php

declare(strict_types=1);

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
    */

    'handoff_point' => (bool) env('DELIVERY_HANDOFF_POINT', true),

];
