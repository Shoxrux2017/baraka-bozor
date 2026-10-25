# Безопасность данных (Data safety) — ответы для Play Console

Где: Play Console → приложение → **Контент приложения** (App content) → **Безопасность данных** (Data safety). Ответы ниже — по коду приложения на момент первой загрузки (`DL-116` (7)). Если в форме появится вопрос, которого здесь нет, пришлите скриншот — отвечу.

## Шаг 1. Сбор данных и безопасность (Data collection and security)

| Вопрос формы | Ответ | Почему |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Имя, телефон, адрес, заказы |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Приложение говорит с сервером только по `https://` |
| Which methods of account creation does your app support? | **Other** → «Phone number and a one-time code» | Вход по номеру и коду, без пароля |
| Delete account URL | `https://api.<домен>/account-deletion` | Публичная страница, `DL-94` (2) |
| Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account? | **No** | Удаляется только весь аккаунт |

## Шаг 2. Типы данных (Data types)

Отметьте только эти. Для всех: **Shared — No**. Telegram, Google Maps и Firebase обрабатывают данные по нашему поручению (service providers), это не «передача» в смысле Google.

| Категория → тип | Collected | Ephemeral | Required / Optional | Purposes | Откуда |
|---|---|---|---|---|---|
| Personal info → **Name** | Yes | No | Required | App functionality, Account management | Имя при первом входе; сборщик и курьер видят, чей заказ |
| Personal info → **Phone number** | Yes | No | Required | App functionality, Account management, Fraud prevention, security, and compliance | Вход по коду; ограничения частоты; список заблокированных номеров |
| Personal info → **Address** | Yes | No | Required | App functionality | Адрес доставки: улица, дом, ориентир |
| Location → **Precise location** | Yes | No | Optional | App functionality | Точка адреса на карте и кнопка «Где я»: положение телефона читается только по нажатию |
| Location → **Approximate location** | Yes | No | Optional | App functionality | Если человек разрешил только приблизительное местоположение (Android 12+), «Где я» ставит карту по нему, и эта точка может стать точкой адреса |
| Financial info → **Purchase history** | Yes | No | Required | App functionality | Заказы, суммы, оплата наличными |
| App activity → **In-app search history** | Yes | **Yes** | Optional | App functionality | Поиск товаров и адреса: сервер отвечает и ничего не хранит |
| App activity → **Other user-generated content** | Yes | No | Optional | App functionality | Комментарии к товарам и доставке, ответы сборщику, оценки и отзывы, причины отмены |
| App activity → **Other actions** | Yes | No | Optional | App functionality | Избранные товары хранятся на сервере |
| App info and performance → **Crash logs** | Yes | No | Required | Analytics | Google Maps SDK собирает сбои карты |
| App info and performance → **Diagnostics** | Yes | No | Required | Analytics | Google Maps SDK: сведения о запросах карты |
| Device or other IDs → **Device or other IDs** | Yes | No | Required | App functionality | Токен уведомлений (Firebase) на нашем сервере; идентификатор установки Firebase; псевдонимный идентификатор Maps SDK |

Не отмечать: Email, User IDs, Race, Political, Sexual orientation, Other personal info, все Financial info кроме Purchase history, Health, Messages, Photos and videos, Audio, Files, Calendar, Contacts, App interactions, Web browsing, Installed apps, Other app performance.

## Шаг 3. Что увидят покупатели

После сохранения Google покажет на странице приложения: «No data shared with third parties», «Data is encrypted in transit», «You can request that data be deleted», и перечень собираемых типов. Это ожидаемо.

## Резервные копии

Страница удаления и политика конфиденциальности говорят, что стёртые данные остаются в зашифрованных резервных копиях до шести месяцев (`DL-104` (6)). В форме Google отдельного поля для этого нет.

## Когда ответы пересматриваются

- появится онлайн-оплата (волна 5): Financial info → Payment info, если приложение будет передавать платёжные данные;
- добавится аналитика или отчёты о сбоях от нас самих;
- приложение начнёт читать положение телефона не только по нажатию «Где я».
