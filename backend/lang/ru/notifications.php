<?php

declare(strict_types=1);

return [
    'order_accepted' => [
        'title' => 'Заказ принят',
        'body' => 'Заказ №:number принят. Скоро начнём собирать.',
    ],
    'shopping_assigned' => [
        'title' => 'Новый заказ',
        'body' => 'Вам назначена сборка заказа №:number.',
    ],
    'approval_required' => [
        'title' => 'Нужен ваш ответ',
        'body' => 'Сборщик задал вопрос по заказу №:number. Пожалуйста, ответьте.',
    ],
    'approval_answered' => [
        'title' => 'Покупатель ответил',
        'body' => 'Покупатель ответил на вопрос по заказу №:number.',
    ],
    'shopping_completed' => [
        'title' => 'Заказ собран',
        'body' => 'Заказ №:number собран. Оплата курьеру наличными: :amount.',
    ],
    'payment_required' => [
        'title' => 'Ожидается оплата',
        'body' => 'Заказ №:number собран. Пожалуйста, оплатите :amount.',
    ],
    'courier_started' => [
        'title' => 'Курьер в пути',
        'body' => 'Заказ №:number едет к вам.',
    ],
    'order_delivered' => [
        'title' => 'Заказ доставлен',
        'body' => 'Заказ №:number доставлен. Спасибо за покупку!',
    ],
    'order_cancelled' => [
        'title' => 'Заказ отменён',
        'body' => 'Заказ №:number отменён.',
    ],
    'shopping_order_cancelled' => [
        'title' => 'Заказ отменён',
        'body' => 'Заказ №:number отменён. Собирать его не нужно.',
    ],
    'delivery_assigned' => [
        'title' => 'Новая доставка',
        'body' => 'Вам назначена доставка заказа №:number.',
    ],
    'delivery_cancelled' => [
        'title' => 'Доставка отменена',
        'body' => 'Заказ №:number отменён. Доставлять его не нужно.',
    ],
    'cancellation_rejected' => [
        'title' => 'Заказ не отменён',
        'body' => 'Заказ №:number не отменён и продолжает выполняться.',
    ],
];
