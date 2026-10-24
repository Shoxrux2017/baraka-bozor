# W4-7 Notifications on the Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every event of `docs/05` section 18, plus the Owner's new `cancellation_rejected`, queues a push to the right person after the action commits, rendered in their language and recorded in `notification_deliveries`, sent through a `PushSender` port that has only a fake until W4-8.

**Architecture:** Each action calls `NotificationService` right where it writes the event's history row, inside its transaction; the service dispatches `SendNotification` with `afterCommit()`, so a rolled-back action sends nothing and a replay or natural repeat, which writes no history, sends nothing again. `SendNotification` checks the recipient and the push's age and writes one `queued` delivery row per active device, then dispatches one `DeliverPush` per row. `DeliverPush` sends through `PushSender` and retries a transient failure three times. Neither job touches the order.

**Tech Stack:** Laravel 13 (PHP 8.4), PostgreSQL, the database queue, PHPUnit.

**Spec:** `docs/DECISIONS.md` `DL-104` (10) (the triggers table), `docs/05-business-rules.md` section 18, `docs/08-database.md` section 26, `docs/07-architecture.md` section 24, `tasks/WAVE_4.md` W4-7. The Owner's answer to Wave 4 question 3 (2026-10-24): **yes**, the Customer is told when an Operator rejects their cancellation request, as a thirteenth event `cancellation_rejected`, with no reason in the text.

## Global Constraints

- Backend commands run inside Compose from the repository root: `docker compose -f docker/compose.yaml exec -T app <command>`. Never run `migrate:fresh`, `db:wipe`, `db:seed` or any `--env=testing` artisan command; `php artisan test` alone touches the test database.
- No new dependency. No change outside `backend/` except the docs of Task 6.
- Every new PHP file: `declare(strict_types=1);`, `final` classes, constructor-promoted `readonly` properties, the module's namespace `App\Modules\Notifications\...`; models in `App\Models`, enums in `App\Models\Enums`, like `PushDevice` and `OrderHistoryEvent`.
- Push texts carry the order number and, for `shopping_completed` and `payment_required`, the amount. Never a name, a phone or an address (`BR-NOTIF-002`, `DL-104` (10)).
- The push data is exactly `['event' => <type value>, 'order_id' => <order uuid>]`, both strings.
- An actor is never notified of their own action, except by `order_accepted`. One action sends a person one push.
- Dispatch only through `SendNotification::dispatch(...)->afterCommit()`. Jobs never write to `orders` or any order table.
- A transient send failure is retried three times: `DeliverPush::$tries = 4`, release delays `[30, 120, 600]` seconds. A push older than one hour (`NotificationService::MAX_AGE_SECONDS = 3600`) is not sent.
- Money in a text: thousands grouped by U+00A0 (`mb_chr(0xA0)`), a U+00A0 before the currency, `so'm` in Uzbek, `сум` in Russian — `docs/07` section 27, as the app's `MoneyFormat`.
- A push token, a title or a body is never logged.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A cancellation path that tells nobody, or tells someone twice: seven paths cancel an order (Task 5 lists them); each gets its own test.
2. An actor told of their own action: a Shopper whose "unavailable" empties the order, a Customer who cancels directly or rejects the last line (Task 5 tests).
3. A rolled-back action that still pushes (Task 3: an action inside a transaction that throws afterwards sends nothing).
4. Erasing a Customer who has delivery rows: the devices are deleted, the rows keep `push_device_id = null`, the erasure succeeds (Task 1 schema test, Task 5 erasure test).
5. Time: a push queued more than an hour ago, at fan-out or at a retry, is not sent (Task 3, with `travelTo`), and a `preferred_language` other than `uz`/`ru` renders Uzbek (Task 2).

---

### Task 1: The delivery record, the types and the push port

**Files:**
- Create: `backend/database/migrations/2026_10_24_000001_create_notification_deliveries_table.php`
- Create: `backend/app/Models/NotificationDelivery.php`, `backend/database/factories/NotificationDeliveryFactory.php`
- Create: `backend/app/Models/Enums/NotificationType.php`, `backend/app/Models/Enums/NotificationDeliveryStatus.php`
- Create: `backend/app/Modules/Notifications/Push/PushSender.php`, `PushMessage.php`, `PushSendResult.php`, `FakePushSender.php`
- Create: `backend/app/Modules/Notifications/NotificationsServiceProvider.php`, `backend/config/notifications.php`
- Modify: `backend/.env.example`, `docker/production.env.example`, `docker/backup/test-cycle.sh` — `PUSH_DRIVER=fake` beside each `LOGIN_CODE_DRIVER` line
- Test: `backend/tests/Feature/Schema/NotificationDeliveriesTableTest.php`, `backend/tests/Feature/Notifications/PushSenderBindingTest.php`

**Interfaces:**
- Produces: `enum NotificationType: string` with exactly these cases and values: `OrderAccepted='order_accepted'`, `ShoppingAssigned='shopping_assigned'`, `ApprovalRequired='approval_required'`, `ApprovalAnswered='approval_answered'`, `ShoppingCompleted='shopping_completed'`, `PaymentRequired='payment_required'`, `CourierStarted='courier_started'`, `OrderDelivered='order_delivered'`, `OrderCancelled='order_cancelled'`, `ShoppingOrderCancelled='shopping_order_cancelled'`, `DeliveryAssigned='delivery_assigned'`, `DeliveryCancelled='delivery_cancelled'`, `CancellationRejected='cancellation_rejected'`.
- Produces: `enum NotificationDeliveryStatus: string` — `Queued='queued'`, `Sent='sent'`, `Failed='failed'`, `Skipped='skipped'`.
- Produces: `NotificationDelivery` model (uuid key, casts `type`/`status` to the enums, `sent_at` datetime, relation `pushDevice(): BelongsTo`).
- Produces: `interface PushSender { public function send(string $pushToken, PushMessage $message): PushSendResult; }`
- Produces: `final readonly class PushMessage(string $title, string $body, array $data)` — `$data` is `array<string, string>`.
- Produces: `final readonly class PushSendResult` with named constructors `sent()`, `failed(string $errorCode)`, `retry(string $errorCode)` and properties `bool $sent`, `bool $retryable`, `?string $errorCode`.
- Produces: `FakePushSender` (singleton): `sent(): list<array{token: string, message: PushMessage}>`; `answerNext(PushSendResult ...$results): void` queues answers, then `sent()` is the default. It never logs or writes anything.
- Produces: binding `PushSender` by `config('notifications.push_driver')` (`env('PUSH_DRIVER', 'fake')`): `fake` → `FakePushSender`; anything else throws a `RuntimeException` naming the setting, the way `AuthServiceProvider` binds `CodeDeliveryGateway` (`fcm` arrives with W4-8).

- [ ] **Step 1: Write the failing schema test** `NotificationDeliveriesTableTest`, in the style of the other `tests/Feature/Schema/*TableTest.php`:
  - `test_the_columns_are_those_of_docs_08_section_26`: `id, user_id, push_device_id, order_id, approval_id, type, status, attempt_count, sent_at, last_error_code, created_at, updated_at`.
  - `test_type_accepts_the_thirteen_values_and_nothing_else`: each `NotificationType::cases()` value inserts; `'order_shipped'` is refused by the check constraint.
  - `test_status_accepts_queued_sent_failed_skipped_only`.
  - `test_deleting_a_device_keeps_the_row_with_no_device`: delete the `push_devices` row; the delivery row stays with `push_device_id` null.
  - `test_the_two_indexes_exist`: `(user_id, created_at)` and `(status, created_at)`.
- [ ] **Step 2: Run** `docker compose -f docker/compose.yaml exec -T app php artisan test --filter=NotificationDeliveriesTableTest` — Expected: FAIL (no table).
- [ ] **Step 3: Write the migration, the enums, the model and its factory.** Columns per `docs/08` section 26: `user_id` FK `users` restrict, `push_device_id` nullable FK `push_devices` `nullOnDelete`, `order_id` nullable FK `orders`, `approval_id` nullable FK `customer_approvals`, `type` and `status` text with check constraints built the way the order-history migration constrains its event type, `attempt_count` integer default 0, `sent_at` nullable timestamptz, `last_error_code` nullable `varchar(64)`.
- [ ] **Step 4: Run the schema test** — Expected: PASS.
- [ ] **Step 5: Write `PushSenderBindingTest`:** `test_the_fake_is_bound_by_default` (resolving `PushSender` twice gives the same `FakePushSender`); `test_an_unknown_driver_fails_naming_the_setting` (`config(['notifications.push_driver' => 'pigeon'])` → `RuntimeException` whose message contains `PUSH_DRIVER`); `test_the_fake_answers_queued_results_then_sent`.
- [ ] **Step 6: Write the port, its value objects, the fake, the config and `NotificationsServiceProvider`** (the module registry discovers it; do not touch `bootstrap/providers.php`). Add `PUSH_DRIVER=fake` to the three env files.
- [ ] **Step 7: Run both tests, then** `vendor/bin/pint --test` and `vendor/bin/phpstan analyse --memory-limit=1G` on the new files — Expected: PASS, no errors.
- [ ] **Step 8: Commit** `feat(notifications): the delivery record, the thirteen types and the push port with a fake (W4-7)`.

### Task 2: The texts in two languages

**Files:**
- Create: `backend/lang/uz/notifications.php`, `backend/lang/ru/notifications.php`
- Create: `backend/app/Modules/Notifications/NotificationText.php`
- Test: `backend/tests/Feature/Notifications/NotificationTextTest.php`

**Interfaces:**
- Produces: `NotificationText::render(NotificationType $type, ?string $language, int $orderNumber, ?int $amountUzs): array{title: string, body: string}`. `$language` other than `uz`/`ru` (null included) renders `uz`. Keys are `notifications.<type value>.title|body`, read with `trans(..., locale: $language)`; the only placeholders are `:number` and `:amount`.

The texts, verbatim (`:amount` is the formatted money of the Global Constraints):

| Type | uz title | uz body | ru title | ru body |
|---|---|---|---|---|
| order_accepted | Buyurtma qabul qilindi | Buyurtma №:number qabul qilindi. Tez orada yig'ishni boshlaymiz. | Заказ принят | Заказ №:number принят. Скоро начнём собирать. |
| shopping_assigned | Yangi buyurtma | Sizga №:number buyurtmani yig'ish tayinlandi. | Новый заказ | Вам назначена сборка заказа №:number. |
| approval_required | Javobingiz kerak | Yig'uvchi №:number buyurtma bo'yicha savol berdi. Iltimos, javob bering. | Нужен ваш ответ | Сборщик задал вопрос по заказу №:number. Пожалуйста, ответьте. |
| approval_answered | Mijoz javob berdi | Mijoz №:number buyurtma bo'yicha savolga javob berdi. | Покупатель ответил | Покупатель ответил на вопрос по заказу №:number. |
| shopping_completed | Buyurtma yig'ildi | Buyurtma №:number yig'ildi. Kuryerga naqd to'lanadi: :amount. | Заказ собран | Заказ №:number собран. Оплата курьеру наличными: :amount. |
| payment_required | To'lov kutilmoqda | Buyurtma №:number yig'ildi. Iltimos, :amount to'lang. | Ожидается оплата | Заказ №:number собран. Пожалуйста, оплатите :amount. |
| courier_started | Kuryer yo'lda | Buyurtma №:number sizga yo'lda. | Курьер в пути | Заказ №:number едет к вам. |
| order_delivered | Buyurtma yetkazildi | Buyurtma №:number yetkazildi. Xaridingiz uchun rahmat! | Заказ доставлен | Заказ №:number доставлен. Спасибо за покупку! |
| order_cancelled | Buyurtma bekor qilindi | Buyurtma №:number bekor qilindi. | Заказ отменён | Заказ №:number отменён. |
| shopping_order_cancelled | Buyurtma bekor qilindi | Buyurtma №:number bekor qilindi. Uni yig'ish kerak emas. | Заказ отменён | Заказ №:number отменён. Собирать его не нужно. |
| delivery_assigned | Yangi yetkazish | Sizga №:number buyurtmani yetkazish tayinlandi. | Новая доставка | Вам назначена доставка заказа №:number. |
| delivery_cancelled | Yetkazish bekor qilindi | Buyurtma №:number bekor qilindi. Uni yetkazish kerak emas. | Доставка отменена | Заказ №:number отменён. Доставлять его не нужно. |
| cancellation_rejected | Buyurtma bekor qilinmadi | Buyurtma №:number bekor qilinmadi va bajarilmoqda. | Заказ не отменён | Заказ №:number не отменён и продолжает выполняться. |

- [ ] **Step 1: Write `NotificationTextTest`:**
  - `test_every_type_renders_in_both_languages` (data provider over `NotificationType::cases()` × `['uz', 'ru']`): title and body non-empty, body contains `№1001`, no `:` placeholder left (`assertDoesNotMatchRegularExpression('/:[a-z]/', ...)`).
  - `test_the_amount_is_grouped_with_no_break_spaces_and_the_currency`: `ShoppingCompleted`, 251250 → uz body contains `'251'.mb_chr(0xA0).'250'.mb_chr(0xA0)."so'm"`; ru contains `...'250'.mb_chr(0xA0).'сум'`.
  - `test_an_unknown_or_missing_language_renders_uzbek`: `'en'` and `null` give the uz title of `OrderAccepted`.
  - `test_the_two_files_hold_the_same_keys_and_only_the_two_placeholders`: both files have exactly the thirteen type keys, each with `title` and `body`; every `:word` placeholder in them is `:number` or `:amount`.
- [ ] **Step 2: Run** `--filter=NotificationTextTest` — Expected: FAIL.
- [ ] **Step 3: Write the two lang files from the table and `NotificationText`.**
- [ ] **Step 4: Run the test, Pint, PHPStan** — Expected: PASS.
- [ ] **Step 5: Commit** `feat(notifications): push texts in Uzbek and Russian (W4-7)`.

### Task 3: The service and the two jobs

**Files:**
- Create: `backend/app/Modules/Notifications/NotificationService.php`
- Create: `backend/app/Modules/Notifications/Jobs/SendNotification.php`, `backend/app/Modules/Notifications/Jobs/DeliverPush.php`
- Test: `backend/tests/Feature/Notifications/NotificationServiceTest.php`, `SendNotificationTest.php`, `DeliverPushTest.php`

**Interfaces:**
- Consumes: Task 1 (types, model, `PushSender`, `FakePushSender`), Task 2 (`NotificationText::render`).
- Produces: `NotificationService::notify(NotificationType $type, string $recipientUserId, Order $order, ?string $actorUserId, ?string $approvalId = null): void` — returns without dispatching when `$recipientUserId === $actorUserId` and `$type` is not `OrderAccepted`; otherwise `SendNotification::dispatch(...)->afterCommit()` with the amount `$order->final_total_uzs` for `ShoppingCompleted`/`PaymentRequired` and null otherwise, and the moment `now()`.
- Produces: `NotificationService::notifyCancellation(Order $order, ?string $actorUserId, ?string $shopperUserId, ?string $courierUserId): void` — `OrderCancelled` to the order's Customer, `ShoppingOrderCancelled` to `$shopperUserId` when given, `DeliveryCancelled` to `$courierUserId` when given, each through `notify` (so the actor rule applies).
- Produces: `NotificationService::MAX_AGE_SECONDS = 3600`.
- Produces: `SendNotification(string $type, string $recipientUserId, string $orderId, int $orderNumber, ?int $amountUzs, ?string $approvalId, string $queuedAt)` — scalars only, no models (an erased account must not break unserialisation). `handle(NotificationText $text)`:
  1. recipient missing → return, nothing written;
  2. status not active → one `skipped` row, `last_error_code = 'account_inactive'`;
  3. older than `MAX_AGE_SECONDS` → one `skipped` row, `'expired'`;
  4. no device with `revoked_at` null → one `skipped` row, `'no_device'`;
  5. otherwise one `queued` row per active device (`attempt_count` 0) and `DeliverPush::dispatch($row->id, $title, $body, $data, $queuedAt)` per row.
  Every row carries `user_id`, `order_id`, `approval_id`, `type`.
- Produces: `DeliverPush(string $deliveryId, string $title, string $body, array $data, string $queuedAt)`, `public int $tries = 4`, `handle(PushSender $sender)`:
  1. row not `queued` → return (a re-run sends nothing);
  2. device gone or revoked → `failed`, `'device_revoked'`;
  3. older than `MAX_AGE_SECONDS` → `failed`, `'expired'`;
  4. `attempt_count + 1`, send to the device's token;
  5. sent → `sent`, `sent_at` now; failed → `failed` with the code; retryable → keep `queued` with the code and `release([30, 120, 600][attempts - 1])` while `$this->attempts() < $this->tries`, else `failed` with the code.
  `failed(Throwable)` marks a still-`queued` row `failed`, `'exception'`. No catch blocks.

- [ ] **Step 1: Write `NotificationServiceTest`** (sync queue, `FakePushSender` from the container, a Customer with one active device from `PushDeviceFactory`):
  - `test_a_committed_call_sends_one_push_with_the_event_and_order_id_only`: `DB::transaction(fn () => $service->notify(OrderDelivered, $customer->id, $order, $courier->id))` → `FakePushSender::sent()` has one entry, its token is the device's, `data === ['event' => 'order_delivered', 'order_id' => $order->id]`; one delivery row `sent`, `attempt_count` 1, `sent_at` set.
  - `test_a_rolled_back_transaction_sends_nothing`: notify inside `DB::transaction` that then throws → nothing sent, no delivery row.
  - `test_the_actor_is_not_told_of_their_own_action`: recipient = actor with `CourierStarted` → nothing.
  - `test_order_accepted_reaches_the_customer_who_placed_it`: recipient = actor with `OrderAccepted` → one push.
  - `test_a_cancellation_tells_the_customer_the_shopper_and_the_courier_but_not_the_actor`: `notifyCancellation($order, $operator->id, $shopper->id, $courier->id)` → three pushes with `order_cancelled`, `shopping_order_cancelled`, `delivery_cancelled`; with `$shopper->id` as actor → two.
  - `test_the_amount_reaches_the_shopping_completed_text`: order with `final_total_uzs` 251250 → the body contains `251`.
- [ ] **Step 2: Write `SendNotificationTest`** (run the job's `handle` directly; `Queue::fake()` where the test checks the `DeliverPush` dispatch):
  - `test_an_inactive_account_gets_one_skipped_row` (a blocked Shopper with a device: no `DeliverPush`, one `skipped` row, `account_inactive`, `push_device_id` null).
  - `test_an_account_with_no_active_device_gets_one_skipped_row` (one revoked device → `no_device`).
  - `test_a_push_queued_over_an_hour_ago_is_skipped` (`travelTo` 61 minutes after `queuedAt` → `expired`).
  - `test_each_active_device_gets_a_queued_row_and_a_delivery_job` (two active devices + one revoked → two rows, two `DeliverPush` pushed).
  - `test_the_text_is_in_the_recipients_language` (`preferred_language` `ru` → the pushed `DeliverPush` title is `Заказ доставлен`).
  - `test_a_missing_recipient_writes_nothing`.
- [ ] **Step 3: Write `DeliverPushTest`** (a `queued` row from the factory; the job built with `->withFakeQueueInteractions()`):
  - `test_a_sent_push_marks_the_row_sent`.
  - `test_a_permanent_failure_marks_the_row_failed_with_its_code` (`answerNext(PushSendResult::failed('INVALID_ARGUMENT'))`).
  - `test_a_transient_failure_is_released_with_backoff` (`retry('UNAVAILABLE')` on attempt 1 → `assertReleased(delay: 30)`, row still `queued`, `attempt_count` 1, `last_error_code` `UNAVAILABLE`).
  - `test_the_fourth_transient_failure_marks_the_row_failed` (attempt 4 → `failed`, not released).
  - `test_a_retry_past_an_hour_is_not_sent` (`travelTo` 61 minutes → `failed`, `expired`, nothing sent).
  - `test_a_revoked_device_is_not_sent_to` → `failed`, `device_revoked`.
  - `test_a_row_no_longer_queued_is_left_alone` (row `sent` → nothing sent, row unchanged).
  - `test_the_failed_hook_marks_a_queued_row_failed`.
- [ ] **Step 4: Run** the three tests — Expected: FAIL.
- [ ] **Step 5: Implement the service and the two jobs** per the Interfaces.
- [ ] **Step 6: Run the three tests, Pint, PHPStan** — Expected: PASS.
- [ ] **Step 7: Commit** `feat(notifications): the service and the queued jobs that send and record pushes (W4-7)`.

### Task 4: Triggers of the order's main path

**Files:**
- Modify: `backend/app/Modules/Orders/Actions/CreateOrder.php` (history row ~:94), `AssignShopper.php` (~:121), `AssignCourier.php` (~:123), `CompleteShopping.php` (~:112), `CorrectPrice.php` (~:127), `StartDelivery.php` (~:69), `DeliverOrder.php` (~:112)
- Test: `backend/tests/Feature/Notifications/OrderPathNotificationsTest.php`

**Interfaces:**
- Consumes: `NotificationService::notify` (Task 3), injected through each action's constructor. The call sits right after the history row, inside the same transaction, so every early return for a repeat sends nothing.

| Action | Type | To | Actor |
|---|---|---|---|
| CreateOrder | OrderAccepted | the Customer | the Customer |
| AssignShopper (assign and reassign) | ShoppingAssigned | the new Shopper | the Operator/Admin |
| AssignCourier (assign and reassign) | DeliveryAssigned | the new Courier | the Operator/Admin |
| CompleteShopping, cash order only | ShoppingCompleted | the Customer | the Shopper |
| CorrectPrice, cash order whose `final_total_uzs` was set and changes | ShoppingCompleted | the Customer | the Admin |
| StartDelivery | CourierStarted | the Customer | the Courier |
| DeliverOrder | OrderDelivered | the Customer | the Courier |

An online order's completion sends nothing until Wave 5's `payment_required`.

- [ ] **Step 1: Write `OrderPathNotificationsTest`**, driving each action through its HTTP endpoint the way the existing order tests do, every recipient holding one active device, and asserting on `FakePushSender::sent()` by `data['event']` and token:
  - one test per table row that the right person gets exactly one push of that type and nobody else gets any;
  - `test_a_replayed_order_creation_sends_no_second_push` (same `Idempotency-Key` twice → one `order_accepted`);
  - `test_assigning_the_same_shopper_again_sends_nothing_new`;
  - `test_a_reassigned_shopper_is_not_told_and_the_new_one_is`;
  - `test_an_online_order_completion_sends_nothing`;
  - `test_a_price_correction_that_changes_the_total_sends_the_new_amount` (body contains the new total) and `test_a_correction_to_the_same_price_sends_nothing`;
  - `test_a_replayed_delivery_sends_no_second_push`.
- [ ] **Step 2: Run** `--filter=OrderPathNotificationsTest` — Expected: FAIL.
- [ ] **Step 3: Add the calls** per the table.
- [ ] **Step 4: Run the new test and the existing tests of the seven actions** (`--filter='CreateOrder|AssignShopper|AssignCourier|CompleteShopping|CorrectPrice|StartDelivery|DeliverOrder'`), Pint, PHPStan — Expected: PASS.
- [ ] **Step 5: Commit** `feat(orders): notify on order creation, assignments, completion, price correction, departure and delivery (W4-7)`.

### Task 5: Triggers of approvals and cancellations

**Files:**
- Modify: `backend/app/Modules/Orders/CustomerQuestions.php` (`ask`, ~:64), `Actions/DecideApproval.php` (~:139), `Orders/NothingLeftToBuy.php` (caller side), `Actions/ResolveExpiredApproval.php` (~:102), `Actions/MarkItemUnavailable.php` (~:61), `Actions/CancelOrder.php` (~:105), `Actions/CancelFailedDelivery.php` (~:65), `Actions/DecideCancellationRequest.php` (~:98)
- Test: `backend/tests/Feature/Notifications/ApprovalAndCancellationNotificationsTest.php`

**Interfaces:**
- Consumes: `NotificationService::notify` and `notifyCancellation` (Task 3). Capture the holder's user id before the action ends the assignment.

| Path | Pushes |
|---|---|
| A question (price, quantity, replacement) via `CustomerQuestions::ask` | ApprovalRequired → the Customer, with `approval_id` |
| The Customer's decision that leaves lines to buy | ApprovalAnswered → the current Shopper, with `approval_id` |
| The Customer's decision that empties the order | `notifyCancellation(actor: Customer, shopper: current Shopper)` → the Shopper gets `shopping_order_cancelled` only |
| An Operator's resolution of an expired question that empties the order | `notifyCancellation(actor: Operator, shopper: current Shopper)` |
| A Shopper's "unavailable" that empties the order | `notifyCancellation(actor: that Shopper, shopper: that Shopper)` → the Customer only |
| The Customer's direct cancellation | `notifyCancellation(actor: Customer, shopper: the Shopper whose assignment it ends, if any)` |
| The Customer's cancellation request | nothing (the board shows it) |
| An Operator's cancellation after a failed delivery | `notifyCancellation(actor: Operator, no holder)` |
| An approved cancellation request | `notifyCancellation(actor: Operator, shopper and courier whose assignments it ends)` |
| A rejected cancellation request | CancellationRejected → the Customer |

- [ ] **Step 1: Write `ApprovalAndCancellationNotificationsTest`** through the HTTP endpoints, one test per table row asserting exactly who gets which type and that no one else gets a push, plus:
  - `test_a_question_resolved_by_expiry_alone_tells_nobody`;
  - `test_the_same_decision_on_a_decided_cancellation_request_sends_nothing_again`;
  - `test_an_approved_request_in_delivery_assigned_tells_the_courier`;
  - `test_a_blocked_shopper_gets_a_skipped_row_and_no_push` (block the Shopper after assignment, then the Customer answers);
  - `test_erasing_a_customer_with_delivery_rows_succeeds` (rows remain with `push_device_id` null).
- [ ] **Step 2: Run** `--filter=ApprovalAndCancellationNotificationsTest` — Expected: FAIL.
- [ ] **Step 3: Add the calls** per the table.
- [ ] **Step 4: Run the new test and the existing approval and cancellation tests** (`--filter='Approval|Cancel|Unavailable|Substitution|AskAbout|EraseCustomer'`), Pint, PHPStan — Expected: PASS.
- [ ] **Step 5: Commit** `feat(orders): notify on questions, answers, cancellations and a rejected cancellation request (W4-7)`.

### Task 6: Pruning, the full suite and the documents

**Files:**
- Create: `backend/app/Console/Commands/PruneNotificationDeliveriesCommand.php` (`notification-deliveries:prune`, deletes rows created more than 90 days ago, prints the count, the way `PruneIdempotencyKeysCommand` does)
- Modify: `backend/routes/console.php` (daily 04:00 Asia/Tashkent beside the others; the comment then names only W4-8's device pruning)
- Test: `backend/tests/Feature/Console/PruneNotificationDeliveriesCommandTest.php` (a row of 91 days goes, one of 89 days stays; the schedule lists the command at 04:00 Tashkent, as the existing schedule test checks the others)
- Modify docs: `docs/05-business-rules.md` section 18 (the Customer also gets `cancellation_rejected`); `docs/04-user-flows.md` section 25 ("Reject: the order continues, and the Customer is told"); `docs/08-database.md` section 26 (thirteen values); `docs/07-architecture.md` section 24 (two jobs, the fake until W4-8); `docs/DECISIONS.md` new `DL-112`; `tasks/WAVE_4.md` (W4-7 row, Owner question 3 answered, W4-6's preparation may start before W4-5)

`DL-112 — Notifications from W4-7 (2026-10-24, agent; item 1 Owner)` records: (1) the Owner's yes to question 3: `cancellation_rejected` to the Customer, no reason in the text, which supersedes the twelve values of `DL-104` (10) with thirteen; (2) two jobs, a recipient fan-out and a per-device delivery, so a retry resends to one device only and the job payload holds no push token; (3) the retry as a `release` with 30/120/600 s, no exception and no failed-job row for a transient answer; (4) the hour limit checked at fan-out and at each retry; (5) the actor rule in `NotificationService`, the holder captured before an assignment ends; (6) the fake push driver is allowed in production until W4-8 brings FCM and its boot check, since W4-5 may deploy before W4-8; (7) the texts of Task 2, checked by the Owner on the wave's walk; (8) W4-6's preparation (release signing, version code, build script, store texts) may start before W4-5, the upload waits for it.

- [ ] **Step 1: Write the prune test; run it** — Expected: FAIL.
- [ ] **Step 2: Write the command and the schedule entry; run the test** — Expected: PASS.
- [ ] **Step 3: Update the documents** as listed.
- [ ] **Step 4: Run the full backend suite** `docker compose -f docker/compose.yaml exec -T app php artisan test`, then `vendor/bin/pint --test` and `vendor/bin/phpstan analyse --memory-limit=1G`, then `git diff --check` — Expected: all pass.
- [ ] **Step 5: Commit** `feat(notifications): prune deliveries after 90 days; docs for W4-7, DL-112`.
