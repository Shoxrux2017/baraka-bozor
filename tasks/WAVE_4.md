# Wave 4 — Pilot readiness

Status: **Planned** on 2026-10-23. Plan under workflow v6 (`tasks/README.md`). Scope from `docs/06-roadmap.md` sections 2 and 3; the Owner's decision on Laravel Boost in `DL-103`, the engineering decisions for the wave in `DL-104`. Each task runs by the work recipe: a plan in `docs/superpowers/plans/`, the Owner's "да", then the code.

## Goal

Real Customers order on cash, with the business running on its own server:

1. **The server.** The backend, the queue worker, the scheduler and the web panel run on the Owner's VPS in Uzbekistan, behind TLS, with nightly encrypted backups kept in Uzbekistan and a restore that has been tried.
2. **Login codes.** A login code reaches the phone through Telegram Gateway (interview 10.1).
3. **The app in Google Play.** A signed release build reaches closed testing early, since twelve testers for fourteen days is the longest wait of the wave (`docs/06` section 5).
4. **Push.** Customers, Shoppers and Couriers are told of every event of `docs/05` section 18, plus the final amount of a cash order (`DL-78`), in their own language.
5. **The pilot.** The end-to-end scenario runs on the production server with real codes and real pushes, and the Owner has the pilot checklist.

Online payment and the Eskiz SMS fallback stay in Wave 5. Order history needs no work: "Мои заказы" with its past tab and reorder shipped in kit stage 6 (`DL-91`, `DL-92`).

## Owner gates

Each gate is the Owner's external action (`AGENTS.md` section 14). Work that needs one runs against fakes until it is met. When a gate holds a task, the next task free of gates goes first.

| Gate | Needed by | What the Owner does |
|---|---|---|
| VPS in Uzbekistan and a domain | W4-5 | Picks the provider (interview 10.2). Ubuntu 24.04 LTS, 2 vCPU, 4 GB RAM, 40 GB SSD or more, a public IPv4 address, ports 80 and 443 open. Adds the agent's SSH public key. Registers a domain and points `api.` and `panel.` at the server's address |
| Backup storage in Uzbekistan | W4-5 | A second place, apart from the VPS: an SFTP account or an S3-compatible bucket at another provider or another data centre, about 20 GB. The copies hold Customer data, so they stay in Uzbekistan (ZRU-547 art. 27-1) |
| Telegram Gateway | W4-4 (verification), W4-5 | Signs in at gateway.telegram.org with their Telegram account and fills in the business details. Copies the API token from the account's API page and, at W4-5, restricts it to the server's IP address. Funds the balance through "Add Funds on Fragment", the only way Telegram's guide names; Fragment probably takes TON, which the Owner checks with their accountant. A code costs $0.01 and an undelivered one is refunded. Codes sent to the account's own number are free, which is how W4-4 is verified |
| Google Play | W4-6 | A personal developer account ($25 once, identity check by document); the store shows the Owner's own name as the developer until the account moves to the legal entity. Twelve testers with Google accounts who stay opted in for fourteen days without a break; below twelve, the count starts again. The Owner submits what the agent prepares: the listing, the data-safety answers, the content rating, the reviewers' access |
| Firebase | W4-8 (verification), W4-9 | A Firebase project on the Owner's Google account (the free plan is enough). An Android app registered with the package `uz.barakabozor.app`, and a service-account key for the server. Both files are saved outside the repository, never sent in chat |
| Google Maps keys for the release | W4-6 | The app's key from kit stage 4b (`DL-86`) gains the SHA-1 of the upload key and of Play's app-signing key; the server's Geocoding key is restricted to the VPS's address |

**Owner questions in this wave**, each put on its own when its task reaches it (`AGENTS.md` section 3):

1. **The store reviewers' sign-in.** Interview 7.2 says that test numbers are both how app-store reviewers sign in and empty in production, and `BR-ROLE-011`, `DL-11` and `AGENTS.md` section 5 hold the second half. Google asks an app with a one-time-code login for "reusable login credentials that can bypass" the code. W4-6 cannot upload before this is settled, and the fourteen days wait on W4-6, so this is asked at once, with the plan. **Answered on 2026-10-23: option А, one reviewer phone in production (`DL-105`).**
2. **The handoff point at launch.** Does it exist (`delivery.handoff_point`, on by default, interview 1.1)? Asked at the deployment, W4-5 (Wave 3 risk list).
3. **A rejected cancellation request.** Should the Customer get a push when the Operator rejects it? `docs/05` section 18 has no such event. Asked at W4-7. **Answered yes, 2026-10-24 (`DL-112` (1)).**

The launcher icon and the store graphics are drawn in Claude Design while W4-2 to W4-5 run, so the Owner's approval of them never holds W4-6.

## Tasks

| # | Task | Gate | Status |
|---|---|---|---|
| W4-1 | Laravel Boost trial (`DL-103`, `DL-106`) | — | Merged (#110); removed unused (#112, `DL-108`) |
| W4-2 | Production runtime: images, `docker/compose.prod.yaml`, Caddy, CORS, proxies, the worker, the scheduler and its pruning | — | Merged (#111) |
| W4-3 | Backups: nightly encrypted copies off the host, the restore script | — | Merged (#113) |
| W4-4 | Login codes through Telegram Gateway | Telegram (verification) | Merged (#114); verified, the no-Telegram answer at W4-5 (`DL-111` (3)) |
| W4-5 | First deployment to the Owner's VPS; the web panel published | VPS, domain, backup storage, Telegram | Planned |
| W4-6 | Android release build and closed testing | Google Play, W4-5 | Planned |
| W4-7 | Notifications on the server: deliveries, intents from every action, templates, the queued sender with a fake | — | Merged (#116) |
| W4-8 | Firebase Cloud Messaging sender; device pruning | Firebase (verification) | Planned |
| W4-9 | Push in the app: Firebase token, permission, banners, opening the order | Firebase | Planned |
| W4-10 | Carried P3 fixes | — | Done |
| W4-11 | Wave closure and the pilot checklist | all | Planned |

The order of work is the table's. W4-6 starts as soon as W4-5 is live, because its fourteen days run while W4-7 to W4-10 are built; testers then receive the later builds through the track. W4-6's preparation (release signing, version code, build script, store texts) may run before W4-5; the upload waits for it (`DL-112` (8)).

## Task notes

**W4-1. Laravel Boost trial.**

- Before anything is installed, check that `laravel/boost` supports Laravel 13 and that its MCP server runs inside the `app` container (`docker compose -f docker/compose.yaml exec -T app php artisan boost:mcp`). If either fails, the task ends with a note to the Owner and no pull request.
- A dev dependency, with the reason in the commit (`AGENTS.md` section 7). `boost:install` must not write `AGENTS.md`, `CLAUDE.md` or `.mcp.json`; `git status` is checked before the commit.
- After the first backend task that follows, the Owner hears in one line whether Boost was used. If it was not, a small pull request removes it.
- Removed on 2026-10-24 (#112, `DL-108`): its tools never reached the agent's session during W4-2, nor at the start of W4-3.

**W4-2. Production runtime** (`DL-104` (3) to (5), (8)).

- A production image: PHP 8.4 FPM with opcache, no dev dependencies, no source mounted; the same image runs the app, the worker (`queue:work`) and the scheduler (`schedule:work`).
- `docker/compose.prod.yaml` with `caddy`, `app`, `worker`, `scheduler` and `db` (`postgres:17-alpine` with the UTF-8 type `DL-20` requires). Only Caddy publishes ports. Every service restarts on failure, and Docker rotates the logs. The application logs to stderr and Caddy keeps no access log (`DL-104` (3)). Each container builds its caches when it starts.
- The Caddyfile: `api.<domain>` serves PHP, the public pages and `/storage` with long cache headers and the panel's origin for images (`DL-34`); `panel.<domain>` serves the static build with `index.html` uncached.
- `config/cors.php` allows only `CORS_ALLOWED_ORIGINS` on `api/*`. `TRUSTED_PROXIES` names Caddy's network, and a test proves that the per-IP login limit sees the client's address behind it.
- `docker/production.env.example` lists every variable the server needs, with no values. The boot refuses a production environment that lacks the database password, the app key or the code driver.
- The scheduler's entries (`DL-104` (8)), each with a test that a second run changes nothing. Now: idempotency keys, login challenges and failed jobs, daily at 04:00 Tashkent (`DL-107` (7)). With W4-7 and W4-8: the notification deliveries and the devices.
- Verified on the development machine: the production stack comes up under its own Compose project name and its own ports, with Caddy's internal certificates, and the Wave 3 walkthrough passes against it. No container or volume of another project is touched (`AGENTS.md` section 11).
- **Rehearsal, 2026-10-23** (project `bb-prod-local`, `127.0.0.1:8443`, API `https://localhost:8443`, panel `https://panel.localhost:8443`):
  - With the production env file:
    - only Caddy publishes a port;
    - the worker and the scheduler run, and `approvals:expire` runs every minute;
    - no `laravel.log` exists in any container;
    - the database is `UTF8` with `en_US.utf8`;
    - FPM keeps the environment, writes no access log and has 12 children; PHP has 256M and opcache without timestamp checks;
    - the code and `vendor/` belong to root, `storage/` and `bootstrap/cache` to `www-data`.
  - The boot check:
    - a blank key, an `http://` URL and an empty driver are refused by name;
    - an eleventh code request in a minute with a forged `X-Forwarded-For` is answered `429`.
  - The edge:
    - `/up` and `/account-deletion` answer `200`. `/legal/privacy` answers `404` until the Admin publishes it.
    - A preflight from the panel's origin is allowed, cached for two hours and carries no credentials. `Retry-After` is exposed.
    - No `Server` or `X-Powered-By` header is sent.
    - The panel's files revalidate, and a deep link serves `index.html`.
    - A `502` for a search with phone digits is logged as `?redacted`.
    - The services came back by themselves after Docker Desktop restarted.
  - With `APP_ENV=local` on the same image and stack:
    - the Wave 1 walkthrough passes 40 of 41 steps. The one failure is the script's own rewrite of `localhost` to `127.0.0.1`, over which TLS has no name. The image is written by `www-data` and served with a year's cache and the panel's origin.
    - The Wave 3 walkthrough with `WALKTHROUGH_SCHEDULER=1` passes 72 of 72, the scheduler writing the expiry.
    - The panel, built for `https://localhost:8443/api/v1`, signs the Admin in across origins and shows the board.
  - The base `php:8.4-fpm` (Debian 13) could not run on this machine: Docker Desktop's store holds a broken copy of its PHP layer since a crash. The rehearsal image was built on Debian 12. CI's job "Production image builds" builds the committed base on every pull request.

**W4-3. Backups** (`DL-104` (6)).

- A `backup` container runs a nightly job at 03:00 Tashkent: `pg_dump` in custom format and the images volume, into a restic repository on the backup storage; retention 7 daily, 4 weekly, 6 monthly; `restic check` weekly. Its credentials and password are its own, not the app's.
- Each run records its outcome, which `docker/deploy.sh` and the Owner's checklist read.
- `docker/backup/restore.sh` restores a chosen snapshot into a scratch stack.
- The restic password lives on the server and with the Owner, who stores it in a password manager or on paper; a lost password means the copies cannot be read.
- Verified locally against a local restic repository: back up, wipe the scratch stack, restore, and the walkthrough passes on the restored data.
- Done on 2026-10-24 (#113, `DL-109`). The rehearsal on `bb-prod-local`:
  - a night's backup, then `down -v` and `restore.sh`;
  - every table's fingerprint and the uploaded image byte for byte equal;
  - an Admin's upload works on the restored stack;
  - the Wave 3 walkthrough passes on the restored data, 72 of 72;
  - a run scheduled by supercronic fired at 09:42 +05:00 and, as documented, failed at the dump until `create-role.sh` ran, then succeeded.
  - It found one defect that the tests had missed: the backup's mount made the empty images volume root's, so uploads failed (`DL-109` (2)).

**W4-4. Login codes through Telegram Gateway** (`DL-104` (9)).

- `TelegramGatewayCodeDelivery` behind `CodeDeliveryGateway`, selected by `LOGIN_CODE_DRIVER=telegram`, with `TELEGRAM_GATEWAY_TOKEN`.
- The refusal `409 code_delivery_unavailable` for a number Telegram cannot reach (`docs/09` sections 6 and 52), with no challenge left behind. The app's sign-in, Customer-mode and account-deletion code screens show words for it.
- The cost guard of `DL-104` (9): the existing per-address limit counting an IPv6 address by its /64, and the daily ceiling of paid checks for phones that hold no active account, with warnings at half and at the ceiling. A test proves that an existing Customer and a Shopper still receive codes above the ceiling.
- Tests against a fake HTTP server, including the provider's refusals, a timeout, and proof that neither the code nor the token reaches a log or an exception message.
- The reviewer phone of `DL-105`: its own setting and fixed code beside the test phones, allowed in production and refused at boot when its code is the development code; it never receives a staff step, and no Shopper or Courier account can be created on it. `BR-ROLE-011`, `docs/09` section 6 and `AGENTS.md` section 5 are updated with it.
- Verified with the Owner's token on the Owner's own number, which costs nothing. Until then the driver stays `fake` locally. Done on 2026-10-24 (`DL-111`): the code arrived and signed in, and an unallocated number answered `409`. A number without Telegram met an empty balance, so that check moved to W4-5.

**W4-5. First deployment.**

- Server preparation, written as a script in `docker/DEPLOY.md`:
  - a deploy user;
  - key-only SSH;
  - a firewall open on 22, 80 and 443;
  - unattended security upgrades;
  - Docker;
  - a read-only deploy key for the repository.
- A tagged release deployed by `docker/deploy.sh` (`DL-104` (7)): a dump before the migrations, a `503` with `Retry-After` while the app is replaced, the previous image kept for a rollback. The first Admin is made by the one-time command (`BR-ROLE-009`), whose temporary password goes to the Owner directly. The Owner then enters the business settings in the panel.
- The Gateway balance is funded before the first code. Then one code request for a number the Owner controls that has no Telegram, a spare SIM for example, must answer `409 code_delivery_unavailable`. The string behind it is read with one direct `checkSendAbility` call, as at W4-4, since the backend does not log an unreachable answer. A `503` instead leaves its string in the log; that string joins `TelegramGatewayCodeDelivery::UNREACHABLE` only when it means the number cannot be reached (Telegram's reference says so, or a second number without Telegram gives the same answer), never a token, address or balance error (`DL-111` (3)).
- Every Shopper's and Courier's number is checked to reach Telegram, since staff sign in with a code first (`DL-77`).
- The Telegram token is restricted to the server's address.
- The Owner is offered an external check that alerts on a downed server and on a night without a backup, and that watches the log for the two ceiling messages (`Login code daily ceiling half used.`, `Login code daily ceiling reached.`) and for `Telegram Gateway refused a login code.` with any reason (`DL-111` (4)); these warnings reach the Owner only through it or a log alert.
- Checked on the live server:
  - Caddy and the app see public client addresses, not the Docker bridge gateway: a Docker userland proxy would make every client one address and share the per-IP limits. The fix is in Docker's configuration or host networking for Caddy, not `TRUSTED_PROXIES`. In that gateway case a client could also send `X_Forwarded_For` with underscores, which Caddy's FastCGI transport maps onto the same variable as its own header (W4-2 security review, below the bar). If the gateway case is ever accepted, Caddy drops the underscore spellings with `header_up -X_Forwarded_For`, `-X_Forwarded_Host` and `-X_Forwarded_Proto`;
  - the panel's `current` link inside `PANEL_ROOT` is relative, since an absolute host path does not resolve inside Caddy's `/srv/panel` mount;
  - TLS on both hosts;
  - the public pages `/legal/privacy` and `/account-deletion`, which W4-6 needs;
  - a sign-in by a Telegram code;
  - `approvals:expire` running from the scheduler;
  - the first nightly backup, then a restore of it into a scratch stack on the server. That scratch env file uses `APP_ENV=local` (the production boot check refuses the fake driver, `DL-110` (7)), `localhost` hosts, fake drivers and blank provider keys (Telegram, FCM, payments), because `restore.sh` ends with `up -d`, which starts a worker and a scheduler on a copy of production data. Write this into `docker/DEPLOY.md`.
- The Owner's question 2 is asked here, and the answer is set in the server's environment.
- The test-phone list is empty in production (`BR-ROLE-011`). The reviewer phone and its code of `DL-105` are set in the server's environment, and its account "Проверка Google" is created.

**W4-6. Android release and closed testing** (`DL-104` (13)).

- The release signing from `frontend/android/key.properties`, which is gitignored, with the upload key kept outside the repository and handed to the Owner. A release build without it fails, and the debug-key fallback and its TODO go.
- The version code taken from `pubspec.yaml`, raised on every upload. `tasks/scripts/build_release.ps1` builds the bundle with `--dart-define-from-file`.
- The launcher icon and the store graphics, drawn and approved earlier (Owner questions above), go into the build and the listing. The listing in Uzbek and Russian, the data-safety answers and the content rating are prepared in `docs/store/`. The data-safety answers and the public deletion page say that backups keep erased data for up to six months (`DL-104` (6)); the answers are redone when push ships (W4-9).
- The Owner uploads to the closed track and invites the testers; the agent gives the exact clicks. The reviewer phone and its code go into Play Console's App access (`DL-105`).
- The release keys' SHA-1s are added to the Maps key, and the address map is checked on a release build.

**W4-7. Notifications on the server** (`DL-104` (10)).

- A migration for `notification_deliveries` (`docs/08` section 26): the thirteen types, the status `skipped`, and `push_device_id` `ON DELETE SET NULL`.
- `NotificationService::notify` is called by each action of the trigger table in `DL-104` (10), beside the history row it writes, and dispatches the job after the commit (`DL-39`). An Admin's price correction on a shopped cash order sends `shopping_completed` again with the new amount.
- The job:
  - renders the text from `lang/uz/notifications.php` and `lang/ru/notifications.php`;
  - skips an account no longer active;
  - sends through the `PushSender` port, which has a fake for now;
  - writes a delivery row per device, or one `skipped` row with its reason;
  - retries a transient failure.
- Owner question 3 is asked here; a yes adds a thirteenth event in this task. Answered yes (`DL-112` (1)): `cancellation_rejected`.
- Tests:
  - every trigger notifies the right person once, and the Customer receives `order_accepted` for their own order;
  - a rolled-back action notifies nobody;
  - a replay or a natural repeat notifies nobody again;
  - no other actor is notified of their own action;
  - a blocked Shopper gets nothing;
  - erasing a Customer who has delivery rows succeeds;
  - the texts in both languages carry no name, phone or address;
  - the payload carries the event and the order's id only.

**W4-8. Firebase Cloud Messaging** (`DL-104` (11)).

- An HTTP v1 sender with the service account's OAuth token, through `google/auth` (a dependency; the reason goes in the commit).
- Answers mapped:
  - `UNREGISTERED`, or `INVALID_ARGUMENT` about the token field alone: the device is revoked; an `INVALID_ARGUMENT` about the message revokes nothing;
  - `429` and `5xx`: retried with backoff, honouring `Retry-After`;
  - anything else: recorded as failed.
- `push-devices:prune` revokes devices unseen for 60 days.
- The production boot check refuses `PUSH_DRIVER=fake` (as `DL-110` (7) does for the login-code driver), and `docker/production.env.example` switches to `PUSH_DRIVER=fcm`.
- `PushSendResult::retry` gains the provider's `Retry-After`, which `DeliverPush` honours.
- The FCM adapter keeps the push token out of exception messages, traces and `failed_jobs` rows (W4-7 security review).
- Tests against a fake HTTP server. Verified with the Owner's project on the emulator with Google Play services, once W4-9 registers a real token.

**W4-9. Push in the app** (`DL-104` (12)).

- `firebase_core`, `firebase_messaging` and `flutter_local_notifications` (dependencies; reasons in the commit). The Firebase options come from the gitignored `frontend/.env.firebase` through dart-defines. A build without them keeps `NoPushTokenSource`, and the web build always does.
- First, before the rest: a push must reach a phone whose app was killed. If the options alone do not do it, the gitignored `google-services.json` and a Gradle plugin applied only when it exists do (`DL-104` (12)).
- `FcmPushTokenSource`. The token change stream re-registers every signed-in account. A registration at each start refreshes `last_seen_at`.
- The permission is asked once, after the first sign-in into a role that receives pushes, on Android 13 and later.
- One notification channel. In the foreground, a banner shows unless the visible screen is that order. A tap opens the order in the event's mode, switching mode when the phone holds both sessions; this works from a cold start too.
- Widget and controller tests with a fake messaging source. Walked on the emulator with real pushes from the local stack and the Owner's Firebase project.

**W4-10. Carried P3 fixes.**

- A list left under a page shows its last answer for a moment after an action on that page (Wave 3 closure walk). After the action, the page tells the list to drop the changed row at once. Done: Riverpod 3 pauses a covered list, so its reload waited for the page to close; a sure answer that takes an order off the Courier's, the Shopper's or the Customer's current list now drops its row first (`DL-113` (1) to (3)).
- The six actions of Customer mode's app bar on a Shopper's or Courier's phone (Waves 2 and 3). Check whether the kit restyle already removed them. Close the row if so, otherwise fix it. Closed with no code change: the redesign removed them (`DL-113` (4)).

**W4-11. Closure.**

- Closure per `tasks/README.md` section 4, on the production server, with a committed `tasks/scripts/wave4_walkthrough.py` that also runs against the local stack.
- The scenario:
  1. A Customer signs in by a Telegram code and places a cash order. Their phone receives `order_accepted`.
  2. The Operator assigns a Shopper in the panel. The Shopper's phone receives `shopping_assigned`.
  3. The Shopper asks a price question; the Customer receives `approval_required` and answers, and the Shopper receives `approval_answered`.
  4. Shopping completes; the Customer receives `shopping_completed` with the amount.
  5. A Courier is assigned and sets off; the Customer receives `courier_started`, then `order_delivered` when the cash is recorded.
  6. A second order is cancelled during shopping by an approved request; the Customer and the Shopper are told.
  7. A tap on each push opens its order, in the right mode on a phone holding two accounts.
  8. The night's backup exists; a restore of it into a scratch stack passes the walkthrough.
- The Owner's pilot checklist: who signs in where, what to try on each phone, what to watch on the board, and who to call when something fails. It says to keep the Telegram Gateway balance above a few days of codes (`DL-111` (4)).

## Risks and housekeeping

| Item | Status |
|---|---|
| Customers without Telegram cannot sign in until Eskiz arrives with the legal entity (interview 10.1). The refusal says so | Accepted for the pilot |
| Staff sign in with a code too (`DL-77`), so a Shopper or Courier whose number has no Telegram cannot work. W4-5 checks every staff number; the pilot checklist repeats it for new staff | Open, W4-5 |
| A flood of code requests to random numbers can reach the daily ceiling and block new Customers' sign-up for the rest of that day; Customers and staff with an account are never blocked (`DL-104` (9)). The ceiling is raised in the server's configuration in minutes, and the warning at half of it gives time to raise it, but it reaches the Owner only once W4-5's external check or a log alert watches for the two ceiling log messages | Accepted for the pilot; the Owner may ask for a higher ceiling |
| Funding Telegram Gateway goes through Fragment, which probably takes TON. Paying in cryptocurrency may have accounting and legal sides in Uzbekistan | Open, Owner |
| An empty Gateway balance refuses every code sent through Telegram with `503`: nobody without a live session can sign in on the phone, Shoppers and Couriers included, a signed-in Customer cannot erase the account, and the app says only that the service is unavailable; the panel's password sign-in is unaffected (`DL-111` (4)). The pilot checklist says to keep the balance above a few days of codes; W4-5's external check watches the log for every Gateway refusal | Open, W4-5 |
| `PHONE_NUMBER_NOT_FOUND` and `PHONE_NUMBER_NOT_AVAILABLE` are unconfirmed: W4-4's check of a number without Telegram met an empty balance (`DL-111` (3)). Were Telegram to answer such a number with another string, its Customer would see "service unavailable" instead of the words for having no Telegram | Open, W4-5 |
| A Shopper or Courier replaced before starting is not notified; `docs/05` section 18 has no such event. They see the order leave their list on the next refresh | Accepted; the pilot shows whether it matters |
| A push is best-effort (`BR-NOTIF-001`). A phone that is off, or that has notifications disabled, learns at the next opening, and the screens keep refreshing themselves | Accepted |
| Push texts pass through Google, and phone numbers through Telegram. The texts carry no personal data beyond the order number and the amount (`DL-104` (10)). Two questions for the Owner's lawyer, with the privacy policy: does sending the phone to Telegram need the Customer's consent, and must the personal-data database be registered under ZRU-547 | Open, Owner, before the pilot |
| A disk-full or downed server is noticed only by people. An external uptime check is an Owner account | Open; offered at W4-5 |
| The backup job cannot prune with append-only storage credentials, and an SFTP repository needs `openssh-client` in the backup image and the key mounted (`DL-109`). W4-5 decides the storage and settles both | Open, W4-5 |
| The stack's env file (`APP_KEY`, `PHONE_FINGERPRINT_KEY`) is in no backup. The Owner keeps it with the restic password; W4-5's Owner checklist says so | Open, W4-5 |
| A stale `success`: a stopped container or a killed run leaves the previous status. The deploy check and the external check of W4-5 test the age of `finished_at` | Open, W4-5 |
| A restore from an older snapshot brings back Customers who erased their accounts after it (`BR-ROLE-013`). The promise stands; the restore runbook of W4-5 re-applies erasures made after the snapshot, the mechanism decided there | Open, W4-5 |
| A staff account made on the reviewer phone before `LOGIN_CODE_REVIEWER_PHONE` was set keeps its password sign-in: the code paths refuse that phone, `AuthenticateStaff` does not. W4-6 checks, when the "Проверка Google" Customer account is created, that no staff account holds that phone | Open, W4-6 |
| iOS push: the code is written and the configuration waits for a Mac and an Apple account (`docs/06`) | Open until a Mac exists |
| Carried from Wave 3: the scheduler runs nowhere until Wave 4 deploys one (`DL-54` (8)) | Closes with W4-5 |
| `worker` and `scheduler` do not mount the images volume; a future job that writes images must get it (W4-2 review) | Open, note |
| The other Symfony components stay on 8.0, past its maintenance, while `symfony/http-foundation` is on 8.1 (`DL-107` (10)). Move `symfony/*` to 8.1 before W4-5 | Open, W4-5 |
| Carried from Wave 2: CORS in production | Closed by W4-2 (`DL-107` (6)) |
| Carried from Wave 2: device pruning, the push token change stream | Close with W4-8 and W4-9 |
| Carried from Wave 2: a build whose MapKit key Yandex refuses aborts at launch | Closed: the map is Google's since `DL-86`, and its SDK starts only when a map is shown |
| Carried from Wave 3: the handoff point at launch | Owner question 2, W4-5 |
| Carried from Wave 3, P3: a list under a page; Customer mode's app bar | Closed by W4-10 (`DL-113`) |
| `composer audit` (found at W4-1) reports three advisories in packages the app already had: `symfony/http-foundation` (a ReDoS through the `Cache-Control` request header) and `league/commonmark` (two). They are updated before the first deployment | Closed by W4-2 (`DL-107` (10)) |

## Independent-review findings not acted on

| Task | Finding | Why not acted on |
|---|---|---|
| W4-1 | P3: the two Boost switches live in `backend/.env`, so a checkout whose `.env` predates W4-1 would offer `record-rule` | Every `.env` is copied from `.env.example`, which carries them, and this machine's `.env` has them. Forcing them in code is taken up if Boost stays after the trial. Moot: Boost removed (`DL-108`) |
| W4-1 | P3: the console-and-local gate in `AppServiceProvider` has no test of its own | `GlobalMiddlewareTest` guards what matters, that tests and CI never load Boost or `laravel/mcp`; the gate is removed with Boost if the trial ends. Removed with Boost (`DL-108`) |
| W4-3 | P2 (the first final review): `restore.sh` should recreate the backup role itself | The second final review advised the opposite, and the lead ruled reminder only (`DL-109` (8)). An automatic role would let a scratch stack that kept `COMPOSE_PROFILES=backup` write restored-copy snapshots into the production repository, where `forget` would thin out real nights unseen. A missing role fails loudly: a failure status, no ping, and W4-5's external check |
| W4-3 | P3: an optional `running` status written at the start of a night | The age check of `finished_at` (W4-5, risk row above) already shows a killed run |
| W4-3 | P3: `nocopy` on Caddy's images mount too | Caddy's image has no `/srv/storage`; the probe kept the volume's uid 33 |
| W4-3 | P3: nothing asserts that the backup role is absent right after `restore.sh`, before `create-role.sh` | The role is cluster-wide and the dump holds none (`pg_dump` of one database). The rehearsal saw the scheduled night fail at the dump on the restored stack, which is that absence |
| W4-3 | P3: the cycle exercises no `forget` failure | A forget-only failure needs a repository that breaks between two calls. Its step name comes from the same trap that the dump, backup and config failures prove |
| W4-4 | P3: one docblock line in `LoginCodeCeiling.php` runs longer than its neighbours | Cosmetic; Pint passes and nothing reads differently. Reflowing it alone would be formatting churn (`AGENTS.md` section 7) |
| W4-7 | P3 (re-review): no test resolves `PushSender` under a non-testing environment to prove the non-reporting fake is bound | The provider's choice is one expression on `$app->environment('testing')`; the testing binding and the flag-false fake are each tested, and W4-8 replaces the fake in production with FCM and a boot check |

## Closure

Not yet closed.
