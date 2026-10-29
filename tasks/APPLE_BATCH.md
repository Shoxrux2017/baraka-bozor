# Apple batch

From 2026-10-24 to 2026-10-29 the Owner reviewed every Customer screen, and the three system screens, against Apple's Human Interface Guidelines and motion rules (skills `apple-look` and `apple-motion`). Each review became a live "было / стало" test page in the Claude Design project "BarakaBozor — стиль покупателя", named `Тест … - Apple.dc.html`, and the Owner approved items one screen at a time: 220 items in 23 tests, all approved. This file is the batch's spec: one line per item, grouped into the stages that code them. The test page of a screen is the picture of its "стало" state; a stage's plan reads both.

Rules for every stage:

- One stage is one branch `task/apple-<n>-<name>`, one plan in `docs/superpowers/plans/`, one pull request, one session.
- Stage 1's colours and 44 px controls are the baseline every later test was drawn on; later stages do not ask about them again.
- Items marked **Owner** are the Owner's decisions (`AGENTS.md` §3) and go into `docs/DECISIONS.md` as Owner decisions in the stage that codes them. Every other choice a stage makes is the agent's and is recorded there too.
- Items marked **server** need a backend change; the stage records it in `docs/DECISIONS.md` and `docs/09`, and runs `/security-review` before its pull request.
- Items marked **repro** were concluded from reading code. The stage first reproduces the fault on the emulator, and the reproduction becomes the item's test.
- Each stage ends with Flutter's `meetsGuideline(iOSTapTargetGuideline)` passing on the screens it rewrites (stage 1's 44 px rule).
- Amounts the Customer sees stay the server's (`AGENTS.md` §5); a client preview is marked "≈" and is replaced by the server's answer.
- A shared piece (stale-data line, undo bar, deadline chip, skeleton, announcements) is built by the first stage that needs it, in `core/`, and reused by the later ones.

## Stages

| Stage | Screens | Items | Server | Status |
|---|---|---|---|---|
| 1 | Kit colours and sizes (all roles) | 7 | — | Merged (PR #121) |
| 2 | Customer tabs | 5 | — | Merged (PR #122) |
| 3 | Cart and the card's stepper | 8 | — | Merged (PR #123) |
| 4 | Checkout | 10 | — | In review |
| 5 | Product | 9 | — | Planned |
| 6 | Home and categories | 14 | working hours | Planned |
| 7 | Category screen and product lists | 10 | — | Planned |
| 8 | «Рекомендуем» and «Все товары» | 7 | list order | Planned |
| 9 | Search | 8 | — | Planned |
| 10 | Favourites | 7 | favourites order | Planned |
| 11 | Order | 9 | approval amounts and picture | Planned |
| 12 | My orders | 10 | list summary fields | Planned |
| 13 | Order editing | 12 | edit preview, minimum | Planned |
| 14 | Cancellation | 12 | cancel reason | Planned |
| 15 | Rating | 10 | `reviewed_at` | Planned |
| 16 | Profile and name | 18 | — | Planned |
| 17 | Documents | 9 | — | Planned |
| 18 | Addresses | 9 | — | Planned |
| 19 | New address | 12 | reverse geocoding, zone | Planned |
| 20 | Sign-in | 14 | tries left | Planned |
| 21 | Account deletion | 11 | erasure race | Planned |
| 22 | System screens | 10 | — | Planned |

Item `fav-3` is split: its tab part in stage 2, its list part in stage 10.

## Items by stage

### Stage 1 — kit colours and sizes

Applies to every role's screens: Customer, Shopper, Courier and the panel. The kit drawings' `kit/kit.css` and `kit/panel.css` in Claude Design take the same values.

- `cart-1` **Owner** White on brand green is 2.25:1 → button fills `#3A9E46` (3.4:1), green text and links `#2D7D38` (5.1:1).
- `cart-2` Secondary text `#8E948F` (3.1:1) → `#676D68` (5.3:1).
- `cart-3` Red `#F04438` (3.6:1) → `#C0362C` (5.5:1) for red text and red buttons.
- `cart-6` Steppers 36 × 36 → 44; every control is at least 44 × 44 to tap.
- `catpage-5` **Owner** In narrow (compact) product cards the 44 is the tap square and the drawn button stays 32.
- `order-1` **Owner** Amber text `#E8A317` on white (2.2:1) → `#94600A` (5.3:1) everywhere; amber borders and icons stay.
- `rate-1` Rating stars: empty outline `#676D68`, filled `#FFB020` with a `#94600A` edge, wherever stars show.

### Stage 2 — Customer tabs

- `home-1` The tab bar shows labels under the icons; tapping the current tab scrolls its list to the top.
- `fav-2` Favourites gets the header cart button with its count; the badge bumps on a change.
- `fav-3` (tab part) The four tabs keep their place: a switch is instant, with the same scroll and the data already shown; no slide-in, no spinner.
- `orders-10` «Мои заказы» → «Заказы», with the cart button and its count; it bumps after «Повторить».
- `profile-8` The profile header gets a white cart button with its count.

### Stage 3 — cart and the card's stepper

- `cart-4` Removing a line asks nothing: it goes at once and a «Вернуть» bar brings it back.
- `cart-5` A step shows the new quantity at once; the amounts stay the server's.
- `cart-7` Large text: the line sum stands over the stepper instead of shrinking (FittedBox).
- `cart-8` **Owner** Totals and address come before «Добавьте к заказу».
- `cart-9` A removed line folds in 0.26 s and the sums change softly instead of jumping.
- `cart-10` Swipe left removes a line.
- `home-5` Card «+» grows into the stepper; the cart badge bumps, haptic, announcement; at the smallest quantity a trash removes, with «Вернуть».
- `home-6` Taps during the server's wait count: three quick «+» give 2,5, not 1,5 — one request with the result.

### Stage 4 — checkout

- `checkout-1` The recount notice stands above the button and shows "было → стало".
- `checkout-2` «Показать состав» lists the names and the server's line sums; pictures labelled «Помидоры, 2 кг».
- `checkout-3` The layout stays while amounts are recalculated: grey bars instead of figures, never figures for another address.
- `checkout-4` The busy button says «Считаем сумму…» / «Отправляем заказ…».
- `checkout-5` The wish field is editable at once; counter from 120; live error.
- `checkout-6` No address: the link says «Добавить» and a line under the grey button says why.
- `checkout-7` The wish survives a trip to the cart and back.
- `checkout-8` **Owner** One cash row plus the line «Онлайн-оплата через Payme и Click — скоро»; the payment choice returns as real options with Wave 5.
- `checkout-9` Large text: the address link goes under the address; «Итого» stands above the button.
- `checkout-10` The placed card rises from the button, its circle opens, light haptic; reduced motion is static.

### Stage 5 — product

- `product-1` The product opens with the card's data at once; the photo grows from the card.
- `product-2` Add: «Добавляем…», then a check «В корзине» with haptic, then «Открыть корзину» stays.
- `product-3` In-cart changes save themselves, like the card's stepper; nothing is lost on back.
- `product-4` **repro** The note field: «Готово», a tap or scroll closes the keyboard; counter from 250, live error.
- `product-5` Screen reader: the price is one phrase, the quantity is adjustable, the button names the product.
- `product-6` Quantity sheet: keyboard at once, chips 0,5–3 кг, a live «≈» sum and error.
- `product-7` **Owner** «Цена ориентировочная», a one-line promise and «Как считаем» replace the five-line estimate paragraph.
- `product-8` 200 % text: the sum stands beside the stepper and the button is full width.
- `product-9` «−» at the smallest step becomes a trash with «Вернуть».

### Stage 6 — home and categories

- `home-2` **repro** One scroll for the whole home: the address scrolls away, the search sticks.
- `home-3` The green filter button leaves the home; search is full width.
- `home-4` Skeletons while loading; offline keeps the data with «Нет связи · данные на 12:46 · Обновить»; pull to refresh.
- `home-7` The question banner unfolds in 0.26 s with «Осталось 9 мин» (red at ≤ 3), a badge on «Заказы», and folds at expiry.
- `home-8` 200 % text: two columns and wider cards.
- `home-9` Screen reader: address with «доставка», distinct «Все», a card as one stop, «Добавить» names the product.
- `home-10` **Owner** **server** At night the home says «Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00»; the Customer app gets the working hours.
- `cats-1` The title is «Категории».
- `cats-2` The category's cart bar shows on «Все категории» too.
- `cats-3` 200 % text: two columns, names on up to three lines.
- `cats-4` Columns follow the width (target tile 88 × text scale), eight in landscape.
- `cats-5` Press-down 0.96; the picture flies from the grid into the rail's well (Hero) and back; reduced motion cross-fades.
- `cats-6` Pull to refresh, tiles kept offline with the stale line, skeletons, pictures fade in.
- `cats-7` Tiles read as «Бахча, кнопка»; the cart bar is one phrase.

### Stage 7 — category screen and product lists

- `catpage-1` **repro** A rail tap keeps header and rail: press 0.96, one marker glides, selection haptic, only the products cross-fade; re-tap scrolls the products to the top.
- `catpage-2` Skeletons, sections already seen are instant, pull to refresh, the stale line offline.
- `catpage-3` 200 % text: the rail becomes a chips row under the header; products in two full-width columns, three-line names, the price wraps.
- `catpage-4` The cart bar slides up, its sum rolls; at large text an arrow replaces «В корзину →»; the sum stays the server's estimate.
- `catpage-6` **repro** Landscape respects the side safe areas; columns follow the width (four lying).
- `catpage-7` Rail items read «…, выбрано, 1 из 12»; a switch announces «Напитки: 3 товара».
- `rec-3` Every product list gets «24 товара · Как в магазине ⌄» (the category screen too); docs/03 «sort any list» then holds.
- `rec-4` **repro** The next page is asked two rows ahead, with placeholder cards and a fade-in; offline «Нет связи · Повторить» in place. All `KitProductGrid` lists.
- `all-3` The order chooser is a pop-up menu anchored to the button, with a check on the current order; it replaces the bottom sheet everywhere.
- `all-4` A thin scroll indicator while scrolling, its length from the server's total; all long lists.

### Stage 8 — «Рекомендуем» and «Все товары»

- `rec-1` From the home row, the visible cards fly to their grid places and the title into the header, and back; reduced motion cross-fades.
- `rec-2` «Все 24 ›» with the server's total; hidden when the row already holds all (≤ 10).
- `rec-5` The list ends with «Это вся подборка: 24 товара» and «Все товары →»; empty: picture, «Подборка пока пуста», «Все категории».
- `rec-6` Announcements: «Рекомендуем: 24 товара», «Загружаем ещё товары», «Загружено ещё 4 товара», «Это вся подборка».
- `all-1` The wide first tile of «Категории» is «Все товары · 42 товара ›»; press 0.96, the title flies into the header.
- `all-2` **server** «Как в магазине» groups by aisle: category order, headings «Овощи · 8», a sticky chips row; price orders stay flat. The server's default order for this list is category order, then product order.
- `all-5` Screen reader: sort options «выбрано», headings as headings, chip «раздел 2 из 8, выбрано», jumps announced.

### Stage 9 — search

- `search-1` The home's field flies up and stretches into the search field (Hero), the keyboard rises with it; reduced motion cross-fades.
- `search-2` **repro** While typing, old cards dim to 0.45 under a 2 px line, then cross-fade; the count rolls; the first query shows skeletons; offline keeps only the same query's cards with «Нет связи · Повторить».
- `search-3` The field stays full width; «Как в магазине ⌄» sits in the found row.
- `search-4` Matching sections show on top from the first letter (local, from the categories list).
- `search-5` **repro** Scrolling hides the keyboard; no cart bar while the keyboard is up; the bar shows on the landing and the results otherwise (supersedes `DL-83` (3)).
- `search-6` Recent queries: × on each, «Вернуть» for 5 s.
- `search-7` Nothing found: a compact message and the «Рекомендуем» row.
- `search-8` Screen reader: «Найдено: 4 товара» / «Ничего не нашли…», «Стереть запрос», «Очистить недавние запросы», «…, недавний запрос, кнопка».

### Stage 10 — favourites

- `fav-1` **repro** Un-heart: the card melts, neighbours glide, «Убрали из избранного: X · Вернуть» for 5 s; the delete is sent when the bar ends; offline the card returns with a reason.
- `fav-3` (list part) **repro** Hearts set elsewhere fade in at the top; offline the list stays with the stale line. Favourites moves onto `KitProductGrid`.
- `fav-4` **server** «24 товара · Сначала новые ⌄» menu: new, cheaper, dearer.
- `fav-5` **server** Products not sold group at the end under «Нет в продаже · 2» with «Убрать все»; their cards are not links.
- `fav-6` Empty: a heart picture and the «Рекомендуем» row with hearts; a hearted card flies into the list.
- `fav-7` Heart: a short pop, light haptic and a bump of the «Избранное» tab on add; nothing on remove. All cards.
- `fav-8` Screen reader: named hearts, «Избранное: 24 товара, 2 нет в продаже», removal and «Вернуть» announced.

### Stage 11 — order

- `order-2` **repro** A failed refresh keeps the order: «Нет связи · данные на 12:46 · Обновить», pull to refresh.
- `order-3` **Owner** **server** The money effect stands above the answer buttons: «+5 000» / «−28 000», computed by the server in `pending_approval`.
- `order-4` **server** A substitution shows the replacement's photo and label (`pending_approval.replacement` gets `image_url`).
- `order-5` «Осталось 9 мин» chip, red at ≤ 3; the card turns expired at once; the server still judges expiry (`DL-59` (3)).
- `order-6` An answered card folds in 0.26 s into «Вы согласились: 16 500 сум за кг» on the line; haptic; announcement.
- `order-7` New cards unfold; scroll anchoring with a «Сборщик спрашивает ↑» pill; the line flashes; announcement.
- `order-8` Stage labels 12 px, a visible track, a check on past stages, the current one bold, «Этап 2 из 4».
- `order-9` Large text: the sum under the name; stages as a vertical list.
- `order-10` Removed lines group under «Убрали из заказа · N» without «0 сум»; one count in the header.

### Stage 12 — my orders

- `orders-1` An empty «Текущие» says «Сейчас заказов в работе нет», with the last order's card, «Повторить» and «Все прошлые заказы · 25».
- `orders-2` **repro** The segment's thumb slides, the list slides from its side and keeps its place; skeletons on the first visit; counts «Текущие · 2».
- `orders-3` **repro** A failed refresh keeps the list with the stale line; pull to refresh.
- `orders-4` The card's headline is the status, the number small; stages labelled «Принят ✓ · Сборка · В пути · Доставлен»; large text: vertical stages, sum on its own line.
- `orders-5` **repro** **server** The question strip under the status with «Осталось 9 мин» (red ≤ 3), folding at expiry; the list summary carries the earliest pending expiry.
- `orders-6` Changes unfold, the bar fills, a glow, light haptic on a question; a delivered card shows «Доставлен», then folds into «Прошлые» (+1); announcements.
- `orders-7` «Оцените заказ» with five 40 × 44 outline stars; a tap lights up to it with a pop and haptic, then the rating screen; rated: «Ваша оценка».
- `orders-8` **server** Past card: three pictures «+7» and «Помидоры, Молоко домашнее и ещё 8»; the summary carries three picture URLs and two line names.
- `orders-9` Month headings and endless loading with skeletons replace «‹ Страница 1 из 2 ›».
- `orders-11` Screen reader: status first, «этап 2 из 4», «Примерно», «Повторить заказ № 1042», «Текущие, 2 заказа, выбрано», month headings.

### Stage 13 — order editing

- `edit-1` **server** Delivery, fee and total in the list, and a footer «Итого ≈ … · +8 000 сум · было ≈ 91 000» from a server edit preview.
- `edit-2` **server** A live strip «не хватает 41 000 сум» with «Добавить»; save grey with the sum; the minimum comes with the order.
- `edit-3` **repro** × and system back ask «Выйти без сохранения?» with the list of changes.
- `edit-4` The picker stays open: its plus becomes a stepper in the row; a bar «Добавлено: 2 · ≈ … · Готово» (supersedes `DL-52` (1)).
- `edit-5` Sections are photo tiles like «Все категории»; «‹ Все разделы · Овощи».
- `edit-6` A removed line folds in 0.26 s to «— убрана · Вернуть» (44); a new line scrolls into view, opens and flashes green; sums roll; haptic.
- `edit-7` A «Комментарий · замена похожим» row (44) under each line; the sheet has × «Отмена» and «Готово».
- `edit-8` «Нет изменений» / «Сохранить изменения (3)» / «Сохраняем…» / ✓ «Сохранено», then a 4 s banner «Заказ изменён · итого».
- `edit-9` **repro** `order_editing_locked`: an amber note «скоро начнёт покупать — сохраните сразу»; the lock view shows what did not save, «Позвонить в поддержку», «Открыть заказ».
- `edit-10` `product_unavailable`: scroll to the line, a red frame and «Убрать» in it, a footer strip with «Убрать»; save grey until removed.
- `edit-11` **repro** Large text: sum and stepper stacked, the price wraps, one-column tiles.
- `edit-12` **repro** Screen reader: «— убрана из заказа. Вернуть», named actions, announcements with the total.

### Stage 14 — cancellation

- `cancel-1` «Оставить заказ» / «Отменить заказ»; a request says «Отправить просьбу»; the title names the order.
- `cancel-2` Reason chips (Заказал не то, Передумал, Долго ждать, Нужен другой адрес, Другое) sent as the text; «Добавить подробности»; the counter shows from 50 left.
- `cancel-3` «Заказал не то» offers «Изменить заказ»; «Нужен другой адрес» explains cancel and «Повторить заказ».
- `cancel-4` The send button is grey with «Выберите или напишите причину» until a reason is given.
- `cancel-5` The sheet stays with «Отменяем…»; an error stays in the sheet with «Повторить»; ✓ «Заказ отменён».
- `cancel-6` Scroll to the top, the card changes in 0.26 s, a 4 s banner above the bar, success haptic.
- `cancel-7` Shopping starts while the sheet is open: the sheet switches in place to a request (amber note, request title and button), the reason kept.
- `cancel-8` Retry after a lost answer: «Отмена не подтвердилась», an amber note «дважды заказ не отменится», the reason as a quote, «Отправить ещё раз»; the idempotency key rules stay.
- `cancel-9` **repro** The first tap outside hides the keyboard; the draft is kept while the order is open.
- `cancel-10` **server** «Причина: «…»» on a cancelled order; the order answer carries a direct cancel's reason.
- `cancel-11` **repro** Large text: the buttons are pinned above the keyboard.
- `cancel-12` **repro** Screen reader: named field, chip state, announcements, focus to the heading.

### Stage 15 — rating

- `rate-2` On the order card, 44 px stars light up to the tap; the rating screen rises from below and leaves downward.
- `rate-3` Stars fill in a cascade, the tapped one pops, the word fades, light haptic; a finger can slide across.
- `rate-4` Three photos and «Помидоры, Лепёшка и ещё 2 · доставлен сегодня в 13:05»; photos and hint fold at 1–3 stars.
- `rate-5` Reasons fold away at 4–5 but are kept and restored at 1–3, never sent at 4–5; «Можно выбрать несколько» (supersedes the UI half of `DL-92` (6)).
- `rate-6` An example per reason; counter from 450; «На 20 знаков больше…» with «Сократите комментарий».
- `rate-7` «Отправить оценку»; the form freezes while sending; ✓ «Оценка отправлена», success haptic, the card flashes, announcement.
- `rate-8` **repro** «Нет связи · Повторить»; a lost answer locks the form with «Отправить ещё раз» (same body, no key, docs/09 §49); «уже оценили» banner; a calm «Срок оценки прошёл» with «Вернуться к заказу».
- `rate-9` **repro** × and back keep the draft while the app runs; the card says «Оценка не отправлена · Продолжить».
- `rate-10` **server** «сегодня в 13:13», after review «Оператор связался с вами …»; the Customer's rating carries `reviewed_at`.
- `rate-11` **repro** Screen reader: one adjustable control «Оценка: 2 из 5, Плохо»; announcements.

### Stage 16 — profile and name

- `profile-1` «Выйти» is a red row at the bottom with a sheet «Выйти из аккаунта?» (code by SMS to the phone; cart, addresses and orders stay; with two sessions «Режим сотрудника останется»); sign-in fades in.
- `profile-2` Groups «Аккаунт», «Приложение», «Помощь», then «Выйти», then «Удалить аккаунт» last.
- `profile-3` The whole header is the name button with ›; no name shows a white «Указать имя ›» pill; the edit row goes.
- `profile-4` **Owner** Header `#2D7D38`, phone 15 px, the mode pill inside the header (dark translucent, 7:1).
- `profile-5` Large text: name and phone wrap, values go under titles.
- `profile-6` **repro** Rows at once, header and help skeletons in place; offline «Не удалось загрузить профиль · Повторить» in the header.
- `profile-7` Language: a check mark with a pop and haptic, the sheet waits 0.3 s, the profile cross-fades.
- `profile-9` «Мои адреса» shows «Дом» (the chosen address, `DL-75`); «Позвонить в поддержку» with the number and a green call icon; documents get a document icon.
- `profile-10` **repro** Screen reader: the header is one stop «…. Изменить имя, кнопка»; group headings; «Русский, выбрано, кнопка»; the language change is announced.
- `pedit-1` The keyboard is up on open with the caret at the end; × clears.
- `pedit-2` A grey frame, green only while focused, never red; a grey helper «Так вас назовут сборщик и курьер».
- `pedit-3` «Сохранить» is grey until the trimmed name differs; empty: grey «Введите имя».
- `pedit-4` The title is «Изменить имя» / «Указать имя», the header button's words.
- `pedit-5` **repro** The phone is a text block «Номер телефона» with a lock and «По этому номеру вы входите — изменить его нельзя.»
- `pedit-6` **repro** «Сохраняем…», the field frozen in place, ✓ «Имя сохранено» with success haptic; the header name fades in with a soft flash; no snackbar.
- `pedit-7` **repro** A strip «Нет связи — имя не сохранено · Повторить»; a lost answer is checked against the reloaded profile and shown as saved.
- `pedit-8` Back with a new name asks «Сохранить новое имя?» with «Сохранить» / «Не сохранять»; a tap outside keeps editing; unchanged closes at once.
- `pedit-9` **repro** Screen reader: avatar hidden, field and helper one stop, phone one phrase, «недоступна — имя не изменилось», announcements.

### Stage 17 — documents

- `docs-1` One name everywhere; a 24 px large title in the page that fades into the bar on scroll with a hairline; «Редакция от 19 октября 2026».
- `docs-2` Body 16/26, 18 px bold ink headings, 12 px between paragraphs, a drawn dot.
- `docs-3` **repro** Landscape and tablet: a 600 px centred column clear of the camera inset.
- `docs-4` A skeleton with the title and a 0.2 s fade; later opens are instant from a saved copy with a silent refresh.
- `docs-5` Offline: a centred state with a green «Повторить» («Загружаем…»); a saved copy stays with «Нет связи — показана сохранённая копия · Повторить»; unpublished: «Загляните позже» and «Назад».
- `docs-6` Uzbek interface with the Russian fallback text shows «Bu hujjat hozircha faqat rus tilida.»
- `docs-7` **repro** A thin scroll indicator while scrolling.
- `docs-8` Text is selectable: «Копировать · Выделить всё».
- `docs-9` **repro** Screen reader: one stop per item, the date in words, «Загружаем документ…».

### Stage 18 — addresses

- `addr-1` The kit look: white centred bar, white cards like sheet 21, a full-width «Добавить адрес» bottom bar.
- `addr-2` A «⋯» menu (Изменить · Доставлять сюда · Удалить in red) and swipe left; a long swipe deletes.
- `addr-3` Delete at once with a 0.26 s fold and «Удалили «Работа» · Вернуть» for 5 s; the request goes when the bar ends; offline the card returns «Нет связи — адрес не удалён». The home's address sheet does the same (supersedes `DL-33` (2) and `DL-86` (5)).
- `addr-4` The delivery address has a green ring and «Доставка сюда»; «Доставлять сюда» pops with haptic; deleting it says where delivery goes now (newest, `DL-75`).
- `addr-5` The card shows the flat, «Ориентир: …» and an icon by label (home, work, pin).
- `addr-6` **repro** Three skeleton cards; the kit failure block with a green retry.
- `addr-7` Empty: a pin circle, why, one «Добавить адрес».
- `addr-8` After a save the card unfolds and glows; the bar names the address.
- `addr-9` **repro** Screen reader: one stop per card with custom actions, «Действия: Дом», deletion announced.

### Stage 19 — new address

- `naddr-1` «Новый адрес» with «Шаг 1 из 2 · точка на карте»; no panel heading; the hint fades after the first move.
- `naddr-2` The pin lifts 14 px while the map moves and drops with a small squash and light haptic; a fling glides.
- `naddr-3` **Owner** **server** The panel shows the reverse-geocoded address under the pin, also under the preview; display only, never stored or logged; same limits and Google quota as `/customer/address-search`.
- `naddr-4` Opens at the device location if already allowed, else at «Дом»; confirm is grey with «Сначала передвиньте карту к дому» until moved, found or located.
- `naddr-5` **server** Outside the zone is dimmed with a dashed edge and «Сюда пока не возим: 11,5 км…»; confirm grey; the server gives the zone's centre and radius.
- `naddr-6` «Где я» per failure: denied «…Настройки», off «…Включить», 10 s «…Ещё раз».
- `naddr-7` A green «Найти» arrow; the result right under the field.
- `naddr-8` The map shrinks into the preview and back; the whole preview is a button; the pill is 44 / 14 px.
- `naddr-9` **repro** «Далее»; a check on leaving a field; scroll, focus and shake to the first gap; «необязательно» labels; green «Сохраняем…», then ✓.
- `naddr-10` Back from the map asks «Выйти без сохранения?».
- `naddr-11` **repro** Large text: no hint over the pin (the panel says it); house and apartment stacked.
- `naddr-12` **repro** Screen reader: the map stop names the pin; announcements; «обязательное поле».

### Stage 20 — sign-in

Staff sign-in shares the code screens, so `vhod-5` to `vhod-10` change it too.

- `vhod-1` The phone field has a label and bold digits; the button is grey until 9 digits («Введите ещё 3 цифры»); clear ×.
- `vhod-2` Android's Phone Number Hint offers the SIM's number (a new dependency).
- `vhod-3` **Owner** No «Проверьте номер» window; the number shows big with «Изменить» on the code screen.
- `vhod-4` The consent line is 12 px right under the button, links 44 px; «Код придёт в Telegram» moves into the subtitle.
- `vhod-5` **repro** The code screen has a back arrow; back returns to the number (kept); slides in from the right and out to the right.
- `vhod-6` The sixth digit verifies by itself; digits pop; the caret blinks; a «Вставить код» chip.
- `vhod-7` An «Открыть Telegram» button and a «Не пришёл код?» sheet (resend, change number).
- `vhod-8` Spinner with «Отправляем код…» / «Проверяем…» / «Сохраняем…»; boxes turn green with ✓ and haptic.
- `vhod-9` **server** Wrong code: shake, red, clear, haptic, «Осталось 2 попытки» from the server; a big countdown; «Получить новый код» as the main button.
- `vhod-10` Errors carry their action: «Повторить», «Ввести другой номер», «через 42 мин» (Retry-After).
- `vhod-11` Name step: label «Имя», grey until a letter, a grey «Войти с другим номером».
- `vhod-12` ✓ «Готово», then the home with a 4 s green banner, instead of the welcome window.
- `vhod-13` **repro** Large text: the wordmark hides and the page scrolls to the button while the keyboard is up.
- `vhod-14` **repro** Screen reader: named field with a count, digits one by one, announcements.

### Stage 21 — account deletion

Also fixes three defects found in the review: the device keeps `delivery_address.<account>` after deletion; deletion skips `PushRegistrar.beforeLogout`; the server's re-check under lock can burn a consumed code in a race (`EraseCustomer` against `LoginCodeCheck`).

- `del-1` **Owner** A 15 px subtitle «Это навсегда — вернуть аккаунт нельзя.»; two grey groups with icons; «Заказы — без имени, телефона и адреса, для учёта».
- `del-2` «Получить код для удаления» (red on light red) over a bold «Оставить аккаунт»; «Код придёт в Telegram на …».
- `del-3` **repro** The sheet drags 1:1; a fling or half closes it; springs back; rubber band while sending.
- `del-4` «Отправляем код…»; the Customer can leave; offline strip «Нет связи — код не отправлен · Повторить».
- `del-5` An unfinished order morphs the same sheet in place (0.26 s) with the order card.
- `del-6` Boxes and caret are green while typing; red only for a wrong code and the delete button.
- `del-7` The sign-in code items (`vhod-6` to `vhod-10`) apply, but the sixth digit never deletes by itself.
- `del-8` Grey «Введите код из Telegram» / «Введите ещё 3 цифры», red on six digits, «Удаляем аккаунт…».
- `del-9` **repro** A lost answer: «Проверяем…», then «Аккаунт удалён» (a call answered 401 means deleted); offline: strip, code kept.
- `del-10` **Owner** A cross-fade to a calm grey check, success haptic, and true text: orders stay.
- `del-11` **repro** Screen reader: groups as one phrase, «Код из Telegram, 6 цифр, введено 3», reasons, announcements.

### Stage 22 — system screens

- `sys-1` Start: after 1.5 s a grey spinner with «Подключаемся…»; the session slots are checked at once; after 8 s «Нет связи».
- `sys-2` **repro** Handoff: the wordmark glides into its sign-in place (0.45 s, no bounce), the rest cross-fades 0.25 s; reduced motion fades (keeps `DL-76` (3)).
- `sys-3` **repro** Large text: the wordmark keeps a fixed size (a logo).
- `sys-4` «Нет связи» gets a grey 64 px circle instead of the festive green halo; 20 / 15 px text.
- `sys-5` «Нет связи / Проверьте мобильный интернет или Wi‑Fi. Приложение откроется само…» apart from a server error «BarakaBozor сейчас недоступен / Интернет на телефоне в порядке…».
- `sys-6` Retry shows «Проверяем…» at least 0.8 s, then «Связи пока нет · проверено в 9:41» with haptic.
- `sys-7` Checks itself on resume, when the network returns (a connectivity listener, a new dependency) and at 5, 10, 20, 30 s; fades into the app.
- `sys-8` Wrong surface: a grey icon, «Откройте панель на компьютере», role and name, «на телефоне можно делать покупки».
- `sys-9` A green «Войти как покупатель» instead of the outlined «Выйти»; the panel's twin «Откройте приложение» changes too.
- `sys-10` **repro** Screen reader: announcements at start, a reason for an unavailable «Повторить», the result.

## Not in the batch

Noticed in the reviews and left out; each needs its own decision before any code.

- Product questions for the Owner, not asked: browsing before sign-in; telling the Customer that nothing is due for what was already bought when a cancellation request is approved (`BR-CAN-006`); mentioning the six-month encrypted backups on the deletion sheet; a Google Play review prompt after five stars; «recently ordered» in the order editor's picker; «Всё в корзину» on favourites; typo-tolerant search; address suggestions while typing (Places Autocomplete, paid); what to tell someone whose number changed.
- Kit-wide looks for a later review: the field and chip fill `#F9F9F9` on white, outline-button and field borders `#EEF0EF`, the kit app bar's title cut at 200 %, the header's missing scroll-edge effect, Uzbek strings with ASCII `'` instead of `ʻ`.
- Android `values-night` NormalTheme is black while the app is light-pinned; the panel's blank page while it loads; the panel's address (no domain yet).

## Risks

- The 44 stepper squeezes the cart line's sum, which is scaled down to fit. Measured width of the sum: 68 to 52 px at 320 wide, 108 to 92 at 360, 123 to 107 at 375. On a 320 px phone a sum like "≈ 127 600 so'm" is drawn at about 40 % of its size. Stage 3 (`cart-7`) fixes it when it redraws the line (`DL-117` (9)). Fixed: the sum now stands over the stepper when the two do not fit side by side (`DL-119` (4)).

## Review findings not acted on

- Stage 1 re-review, P3: the panel's pending-approval tag now sits on `warningWash`, the same ground as its card, so "pending" shows as text without a pill (still 4.96:1). Ruling: panel only and readable; the smallest fix is a white ground for that tag (`order_actions.dart`, the `tagGround` switch), taken with the next stage that touches the panel.
- Stage 1 re-review, P3, unconfirmed: the panel's language button has a `PanelHitBox` (a `GestureDetector`) around its `PopupMenuButton` without `excludeSemantics`, so a screen reader may meet two actions. Ruling: not reproduced; check it with the panel's next screen-reader pass and wrap it like the pager if it doubles.
- Stage 2 re-review, minor: `PeriodicRefresh._tick` refreshes a shown screen without clearing the flag of a tick skipped earlier, so a refresh that leaves `active` true and a later hide and show can give one extra refresh. Ruling: harmless (one redundant load, no wrong data); the one-line fix (`_skipped = false` in the refreshing branch) goes with the next stage that touches `periodic_refresh.dart`.
- Stage 3 review, minor: `Fold` maps its linear time through different curves when folding and unfolding, so a line that comes back while it folds (a removal that fails at once, offline) jumps before it unfolds. Ruling: cosmetic and short; the fix is to keep the size on reversal (derive the unfolding start from the current size), taken with the next stage that uses `FoldingColumn`. Fixed in stage 4: a reversal keeps the drawn height (`DL-121` (11)).
- Stage 3 review, minor: the quantity queue treats a cart that has not loaded yet as one without the product, so a step then adds at once, and an existing line answers `cart_item_already_exists` and the step is dropped quietly. Ruling: a card or line shows a stepper only once the cart or a wish is known, so the case needs a cart that never loaded; left as is.
- Stage 3 review, minor: the product card starts and stops its grow and shrink from `build()`; a card that scrolls in while its product has a wish but no line yet grows instead of appearing. Ruling: no crash (traced), visual only; a `ref.listen` would be cleaner, taken with stage 5 or 7 when the card is touched.
- Stage 3 review, minor: the cart footer's fit check hard-codes the button's 18 px side padding and the 12 + 1 + 12 divider. Ruling: correct today; whoever changes the button updates the check.
- Stage 3 review, out of scope: the product screen still saves its quantity through the same cart controllers, so a queue send that meets its save on the same line is refused as busy and the queue's wish is dropped quietly. Ruling: stage 5 (`product-3`) moves the product screen onto the queue.
- Stage 3 review, for the Owner's look: at 100 % text on a 360 dp phone a six-digit line sum leaves about 92 px beside the stepper, so many lines stand their sum over the stepper rather than beside it as drawn. Ruling: the walk took a 360 dp screenshot (every line stacks there, five-digit sums too); the Owner chose to keep the stacked line (`DL-120` (1)).
