# The server runbook

How the test stand (W4-5 step 1, `DL-141`) is made, deployed, checked and
repaired. Step 2, production, is the last section. Every command is meant to be
copied; no secret value appears here, and none is ever pasted on a command line
or typed into a chat.

Names used below, to replace once:

| Name | Meaning |
|---|---|
| `<ip>` | the static IP of the instance |
| `<name>` | the DuckDNS name the Owner chose |
| `api.<name>.duckdns.org`, `panel.<name>.duckdns.org` | the API host and the panel host |

The server has no PHP. Everything that runs the application runs in a container,
through `docker/stack.sh`.

## 1. The Owner's clicks

In the AWS Lightsail console (the Owner's account):

1. **Create instance.** Region Frankfurt (`eu-central-1`), platform Linux/Unix,
   blueprint "OS Only" > Ubuntu 24.04 LTS.
2. **SSH key pair.** Under "Change SSH key pair" choose "Upload new" and upload
   the agent's **public** key. Lightsail puts it in `/home/ubuntu/.ssh/authorized_keys`;
   `prepare.sh` copies it to the `deploy` user.
3. **Plan.** The 4 GB bundle that includes a public IPv4 address. Name the
   instance `barakabozor-stand`.
4. **Static IP.** Networking > Create static IP > attach it to the instance. A
   static IP left detached is billed. This is `<ip>`; it survives a stop and start.
5. **Firewall.** Instance > Networking. The IPv4 firewall and the IPv6 firewall
   are separate tables: in **both**, allow exactly SSH (TCP 22), HTTP (TCP 80)
   and HTTPS (TCP 443), and remove every other rule. Docker publishes ports around
   `ufw`, so this firewall is the real guard of 80 and 443.
6. **DuckDNS.** At duckdns.org add the domain `<name>` and set its address to
   `<ip>`. DuckDNS answers every name under `<name>.duckdns.org`, so `api.` and
   `panel.` need no records of their own. Check from any machine:

```text
dig +short api.<name>.duckdns.org panel.<name>.duckdns.org
```

Both lines must show `<ip>`. Caddy asks Let's Encrypt for the two certificates on
its first start, so the names must answer before the first deploy.

Lightsail's "Connect using SSH" button logs in as `ubuntu`; `prepare.sh` keeps
that user and sets no `AllowUsers`.

## 2. Prepare the server

From a checkout on the agent's machine (the clone on the server does not exist
yet), copy the script and run it as root:

```text
scp -i ~/.ssh/barakabozor_vps docker/server/prepare.sh ubuntu@<ip>:
ssh -i ~/.ssh/barakabozor_vps ubuntu@<ip> 'sudo bash prepare.sh'
```

It installs the packages, 2 GB of swap, Docker Engine with the Compose plugin
(userland proxy off, logs rotated), the `deploy` user in the group `docker` with
the same SSH key, key-only SSH, `ufw` on 22, 80 and 443, unattended security
upgrades that reboot at 00:30 UTC when needed, the layout under
`/opt/barakabozor`, and the clone of the public repository. It is safe to run
again. It ends by saying whether `/var/run/reboot-required` exists (then
`sudo reboot` and wait a minute) and that `deploy`'s `docker` group takes effect
at its next login.

From here on, work as `deploy`:

```text
ssh -i ~/.ssh/barakabozor_vps deploy@<ip>
```

The layout:

```text
/opt/barakabozor/
  repo/            the clone (deploy.sh acts only on this one)
  stack.env        the stack's env file          (secret, mode 600)
  backup.env       the backup service's env file (secret, mode 600)
  state/           release, release.previous, deploy.log, deploy.lock
  dumps/           the five newest pre-deploy dumps
  maintenance/     the file `on` exists while a deploy replaces the app
  panel/           releases/<release>/ and the relative link current
  backup-repo/     the restic repository, owned by uid 10001
```

## 3. The two env files

Both are created empty with mode 600 **before** a secret is written, and live
outside the repository.

```text
cd /opt/barakabozor
umask 077
: > stack.env
: > backup.env
```

### The stack's file

The non-secret values (replace `<name>` and the phone list):

```text
cd /opt/barakabozor
API=api.<name>.duckdns.org
PANEL=panel.<name>.duckdns.org
TEST_PHONES='<the test phones the Owner chose, +998 and nine digits, comma-separated>'
cat >> stack.env <<ENV
COMPOSE_PROJECT_NAME=barakabozor
BB_ENV_FILE=/opt/barakabozor/stack.env
API_HOST=$API
PANEL_HOST=$PANEL
PANEL_ROOT=/opt/barakabozor/panel
MAINTENANCE_DIR=/opt/barakabozor/maintenance
EDGE_SUBNET=172.30.77.0/28
APP_NAME=BarakaBozor
APP_ENV=staging
APP_DEBUG=false
APP_URL=https://$API
CORS_ALLOWED_ORIGINS=https://$PANEL
LOGIN_CODE_DRIVER=fake
LOGIN_CODE_TEST_PHONES=$TEST_PHONES
PUSH_DRIVER=fcm
DB_DATABASE=barakabozor
DB_USERNAME=barakabozor
COMPOSE_PROFILES=backup
BACKUP_ENV_FILE=/opt/barakabozor/backup.env
BB_COMPOSE_OVERRIDE=docker/backup/compose.local-repo.yaml
BACKUP_LOCAL_REPOSITORY=/opt/barakabozor/backup-repo
BB_BUILDER_PRUNE=1
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
LOG_CHANNEL=stderr
LOG_LEVEL=info
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=array
FILESYSTEM_DISK=local
APP_LOCALE=en
APP_FALLBACK_LOCALE=en
BCRYPT_ROUNDS=12
LOGIN_CODE_DAILY_LIMIT=500
ENV
```

Every name of `docker/production.env.example` is either in the block above,
generated below, or listed as left out further down. The fixed lines at the end
of the block (`DB_HOST=db`, `LOG_CHANNEL=stderr`, the drivers) are the template's
own; without `DB_HOST=db` the first migration looks for a database on the app's
own address and fails.

The generated secrets, written straight into the file so that none is shown on
the terminal (`openssl` and `/dev/urandom` only; the server has no PHP):

```text
cd /opt/barakabozor
printf 'APP_KEY=base64:%s\n' "$(openssl rand -base64 32)" >> stack.env
printf 'PHONE_FINGERPRINT_KEY=base64:%s\n' "$(openssl rand -base64 32)" >> stack.env
printf 'DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" >> stack.env
printf 'LOGIN_CODE_TEST_CODE=%06d\n' "$(( $(od -An -N4 -tu4 /dev/urandom) % 1000000 ))" >> stack.env
```

Test phones must look random: not a sequence, not round numbers. A code request
answers differently for a test phone than for any other number, so anyone may
probe numbers and find the stand's phones; a random number is not found in a few
guesses. One way to draw a phone:

```text
printf '+99890%07d\n' "$(( $(od -An -N4 -tu4 /dev/urandom) % 10000000 ))"
```

The boot refuses a guessable test code (six equal digits, or a run up or down by
one such as `123456`). The odds are about one in 50,000; if a deploy says so,
replace the `LOGIN_CODE_TEST_CODE` line with a new draw.

The Firebase service-account key (`DL-114` (8)) is copied to the server, encoded
into the file, then destroyed there. From the agent's machine:

```text
ssh -i ~/.ssh/barakabozor_vps deploy@<ip> 'umask 077; cat > /opt/barakabozor/state/fcm.json' < <path to the key file>
```

The file is created with mode 600 inside the private `state/` directory. On the
server:

```text
cd /opt/barakabozor
printf 'FCM_SERVICE_ACCOUNT=%s\n' "$(base64 -w0 state/fcm.json)" >> stack.env
shred -u state/fcm.json
```

Left out on the stand on purpose: `LOGIN_CODE_REVIEWER_*`, `TELEGRAM_GATEWAY_TOKEN`
(no Telegram: `LOGIN_CODE_DRIVER=fake`), `DELIVERY_HANDOFF_POINT` (unset means on;
Owner question 2 is for step 2) and `GOOGLE_MAPS_GEOCODING_KEY` (add it when the
Owner has a server key, or address search by text is unavailable). The full list
of names is `docker/production.env.example`.

What the fake driver means for the testers: it records a code in memory and
delivers nothing, so a tester signs in **only** with a number the Owner gave
them, and the fixed code. A test phone works for every role that signs in with a
code: as a Customer it opens a Customer account; when an Admin has made a Shopper
or Courier account on that number in the panel, the code is followed by the staff
password step (`DL-77`, `docs/09` section 7). The Shopper's and the Courier's
screens are in the app only; the panel serves the Operator, the Admin and the
Manager, who sign in with a password.

### The backup's file

```text
cd /opt/barakabozor
printf 'RESTIC_REPOSITORY=/repository\n' >> backup.env
printf 'RESTIC_PASSWORD=%s\n' "$(openssl rand -hex 24)" >> backup.env
printf 'PGPASSWORD=%s\n' "$(openssl rand -hex 24)" >> backup.env
chmod 600 stack.env backup.env
```

The restic password goes to the Owner too: a lost password means copies nobody
can read. Hand it over by the Owner's own safe channel, never in a chat log. The
same for `APP_KEY` and `PHONE_FINGERPRINT_KEY`, which no backup holds.
`RESTIC_REPOSITORY=/repository` is the path inside the backup container; the
override file mounts `BACKUP_LOCAL_REPOSITORY` there.

## 4. The first deploy

A release is a tag on `main`: `r<yyyy>.<mm>.<dd>.<n>`. On the agent's machine,
from a clean `main` that is on `origin/main`:

```text
git tag r2026.11.19.1 origin/main
git push origin r2026.11.19.1
```

On the server, as `deploy`:

```text
cd /opt/barakabozor/repo
docker/deploy.sh r2026.11.19.1
```

**Compose only through `docker/stack.sh`.** It supplies `--env-file` and the
running release's image tag. A bare `docker compose` has no `BB_RELEASE`, so it
would build and start a `latest` image from the checkout, beside the release that
is running. One-off commands are `docker/stack.sh run --rm app php artisan ...`;
running containers are `docker/stack.sh exec ...`.

The first deploy builds the images (several minutes on 2 vCPU), starts the
database, migrates, starts the stack and gets the certificates. It ignores a
dropped SSH session and writes everything to `state/deploy.log`.

Then the backup role and the repository. `create-role.sh` and `restore.sh` run
Compose themselves and read the override and the image tag from the
**environment**; pass them on the line, never `export` them (an exported
`BB_RELEASE` would outlive the release it names):

```text
cd /opt/barakabozor/repo
BB_COMPOSE_OVERRIDE=docker/backup/compose.local-repo.yaml BB_RELEASE="$(cat /opt/barakabozor/state/release)" \
  docker/backup/create-role.sh /opt/barakabozor/stack.env
docker/stack.sh exec backup restic init
docker/stack.sh exec backup backup.sh
docker/stack.sh exec backup cat /status/backup.json
```

`result` must be `success`. The night also runs at 03:00 Tashkent on its own.

The first Admin (`BR-ROLE-009`) is made with one command that asks for the
temporary password at a hidden prompt, twice. It needs a terminal, so `ssh -t`
from the agent's machine:

```text
ssh -t -i ~/.ssh/barakabozor_vps deploy@<ip> 'cd /opt/barakabozor/repo && docker/stack.sh run --rm app php artisan bootstrap:first-admin <phone> --name="<full name>" --temporary'
```

`<phone>` is the Admin's `+998` number. With `--temporary` the Admin must replace
the password at the first sign-in. The temporary password goes to the Owner
directly. It is not written to a file, a chat or the shell history (the command
takes no password argument). The Owner signs in to the panel, is made to change
it, and enters the business settings.

## 5. The panel and the APK

Both are built on the agent's Windows machine from `main` (`DL-141` (9)); the
scripts' headers list their parameters.

```text
tasks/scripts/publish_panel.ps1 -SshTarget deploy@<ip> -ApiEnv .env.stand [-Identity <key>]
tasks/scripts/build_release.ps1 -Apk -ApiEnv .env.stand [-OutDir <path>]
```

`-ApiEnv` names the one env file in `frontend/` that fixes the API server (default
`.env.release`; never `.env.maps` or `.env.firebase`). For the stand it is
`frontend/.env.stand`, which is ignored by Git (`.env.*`) and holds one line:

```text
BB_API_BASE_URL=https://api.<name>.duckdns.org/api/v1
```

`-Identity` defaults to `~/.ssh/barakabozor_vps`. Both scripts refuse a
modified tree or a HEAD that is not on `origin/main`, and print names, never
values. The APK is written to `frontend/build/release/` as
`barakabozor-<version>-<code>-<api host>.apk` after `apksigner` has proved it is
signed with the upload key.

`publish_panel.ps1` builds the web panel, uploads it to
`/opt/barakabozor/panel/releases/<release>/` and moves the relative link
`/opt/barakabozor/panel/current` to it; Caddy serves `current`. The APK is signed
with the upload key and sent to the testers by the Owner. A later install from
Google Play needs the stand's APK removed first, because Play signs with its own
key. There is no iOS build: a tester with an iPhone tries the panel only.

The address map in a release build needs the upload key's SHA-1 on the app's Maps
key (step 6 of `docs/store/play-console.ru.md`); until the Owner adds it the map
shows "Authorization failure" and a tester cannot place an address. Check the map
on the stand's APK before it goes to the testers.

## 6. Later releases and rollback

```text
cd /opt/barakabozor/repo
docker/deploy.sh r2026.11.20.1
```

It checks the tag (on `main`, not the running one), checks it out, validates the
Caddyfile, builds, dumps the database, turns maintenance on (the API answers
`503 service_unavailable` with `Retry-After: 30`), stops the worker and the
scheduler, migrates, starts everything, reloads Caddy, turns maintenance off and
records the release. It then prints the API check and the age of the last backup,
as warnings only. A failure before maintenance changes nothing: the clone goes
back to the running release.

Back one release:

```text
docker/deploy.sh --rollback
```

It goes one release further back, to `state/release.previous`, and is refused when
the two releases differ in `backend/database/migrations` (migrations only go
forward). The newest five dumps and the images of the running and the previous
release are kept.

```text
docker/stack.sh ps
docker/stack.sh logs --tail 100 app
cat /opt/barakabozor/state/release /opt/barakabozor/state/release.previous
```

## 7. When something fails

`state/deploy.log` holds every run, with times. Read it first:

```text
tail -n 80 /opt/barakabozor/state/deploy.log
```

- **Failed before maintenance** (build, Caddyfile, dump): nothing changed; the
  clone is back on the running release. Fix the cause and deploy a new tag.
- **Failed with maintenance on**: the API answers `503` on purpose, since a
  half-migrated app is worse. The output names the dump taken before the deploy.
  To return the running release to service, once the cause is fixed:

```text
docker/deploy.sh --resume
```

  `--resume` is refused when the database holds a migration the running release
  lacks (deploy a **fixed tag**, a new tag on `main` with the fix), or lacks one
  the running release has (run `docker/stack.sh run --rm app php artisan migrate
  --force` first). A deploy of an older tag, or `--rollback` onto a release that
  lacks a migration the database holds, is refused the same way.
- **`--rollback`**: one release further back, only when no migration differs.
- **A stale lock.** A deploy killed outright leaves `state/deploy.lock`, a
  directory, and the next run says "another deploy holds ...". Check that no
  deploy runs, then remove it:

```text
pgrep -af deploy.sh
rmdir /opt/barakabozor/state/deploy.lock
```

- **The dump as the last resort.** `dumps/` holds the five newest custom-format
  dumps, named `<time>-before-<tag>.dump`. Restoring one replaces the database
  with its older state, so every change since is lost. The schema is dropped and
  made again first, so nothing newer is left behind to block the restore. With
  maintenance on and the application stopped:

```text
cd /opt/barakabozor/repo
touch /opt/barakabozor/maintenance/on
docker/stack.sh stop app worker scheduler
docker/stack.sh exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "drop schema public cascade; create schema public;"'
docker/stack.sh exec -T db sh -c '
  f="$(mktemp)"
  cat > "$f" || exit 1
  code=0
  pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --single-transaction --exit-on-error "$f" || code=$?
  rm -f "$f"
  exit "$code"' < /opt/barakabozor/dumps/<file>.dump
docker/stack.sh run --rm app php artisan migrate --force
docker/deploy.sh --resume
```

  The `migrate` line brings an older dump up to the running release (it does
  nothing when the dump is current); `--resume` refuses until the database has
  every migration of the running release, then starts the stack and turns
  maintenance off. This sequence is rehearsed by `docker/deploy-test.sh`. A
  night's backup is restored the other way, into a new stack (section 8).

## 8. The live checks

Done once on the stand, after the first deploy. Each block is one item of
`tasks/WAVE_4.md` step 1.

**The server reaches Firebase and Google.** Any HTTP status line is a pass; a
timeout or a resolution error is a fail.

```text
cd /opt/barakabozor/repo
for h in fcm.googleapis.com oauth2.googleapis.com maps.googleapis.com; do
  docker/stack.sh exec -T app php -r 'echo $argv[1], " ", @get_headers("https://".$argv[1]."/")[0] ?? "no answer", PHP_EOL;' "$h"
done
```

**TLS on both hosts.**

```text
curl -sSI https://api.<name>.duckdns.org/up | head -n 1
curl -sSI https://panel.<name>.duckdns.org/ | head -n 1
echo | openssl s_client -connect api.<name>.duckdns.org:443 -servername api.<name>.duckdns.org 2>/dev/null | openssl x509 -noout -issuer -dates
```

The first two answer `200`; the issuer is Let's Encrypt.

**`/account-deletion` and the panel's `current` link.**

```text
curl -sS -o /dev/null -w '%{http_code}\n' https://api.<name>.duckdns.org/account-deletion
ls -l /opt/barakabozor/panel/
```

`200`; `current` is a relative link (`current -> releases/<release>`).

**The public client address reaches Caddy and the app.** The staff login allows
twenty refusals per client address per minute (`docs/09` section 8). From the
agent's machine:

```text
for i in $(seq 1 22); do
  curl -s -o /dev/null -w '%{http_code} ' -X POST https://api.<name>.duckdns.org/api/v1/auth/staff/login \
    -H 'Content-Type: application/json' -d "{\"phone\":\"+9989000000$(printf %02d "$i")\",\"password\":\"x\"}"
done; echo
```

The first twenty answer `401`, the last two `429`. From another network (a phone
on mobile data, for example) one such request must still answer `401`, not `429`:
if the app saw Caddy's address instead of the client's, every client would share
one limit. Wait a minute before using the staff login again.

**A test-phone sign-in.** In the APK, or with `curl`, ask for a code for one of the
test phones, then verify it with `LOGIN_CODE_TEST_CODE` (`docs/09` sections 6 and
7). The code is read from `stack.env` by the person who holds the file and is
never copied into a chat.

**`approvals:expire` from the scheduler.**

```text
docker/stack.sh logs --tail 20 scheduler
```

The line for `approvals:expire` repeats every minute.

**The first night's backup on the disk.** After 03:00 Tashkent (22:00 UTC):

```text
docker/stack.sh exec backup cat /status/backup.json
docker/stack.sh exec backup restic snapshots
```

`result` is `success` and `finished_at` is from the last night.

**The restore into a scratch stack.** Never into the live stack: `restore.sh`
stops at "not empty". The scratch stack has its own env file (outside the
repository), `APP_ENV=local`, `localhost` hosts, fake drivers, blank provider
keys, another project name, other ports and `EDGE_SUBNET`, and no
`COMPOSE_PROFILES=backup`:

```text
umask 077
mkdir -p /opt/barakabozor/scratch/panel /opt/barakabozor/scratch/maintenance
S=/opt/barakabozor/scratch/stack.env
cat > "$S" <<ENV
COMPOSE_PROJECT_NAME=bb-restore-test
BB_ENV_FILE=$S
API_HOST=localhost
PANEL_HOST=panel.localhost
PANEL_ROOT=/opt/barakabozor/scratch/panel
MAINTENANCE_DIR=/opt/barakabozor/scratch/maintenance
EDGE_SUBNET=172.30.78.0/28
BB_PUBLISH_ADDRESS=127.0.0.1
BB_HTTP_PORT=18080
BB_HTTPS_PORT=18443
APP_NAME=BarakaBozor
APP_ENV=local
APP_DEBUG=false
APP_URL=https://localhost:18443
CORS_ALLOWED_ORIGINS=https://panel.localhost:18443
LOGIN_CODE_DRIVER=fake
PUSH_DRIVER=fake
DB_DATABASE=barakabozor
DB_USERNAME=barakabozor
BACKUP_ENV_FILE=/opt/barakabozor/backup.env
BACKUP_LOCAL_REPOSITORY=/opt/barakabozor/backup-repo
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
LOG_CHANNEL=stderr
LOG_LEVEL=info
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=array
FILESYSTEM_DISK=local
APP_LOCALE=en
APP_FALLBACK_LOCALE=en
BCRYPT_ROUNDS=12
LOGIN_CODE_DAILY_LIMIT=500
ENV
printf 'APP_KEY=base64:%s\n' "$(openssl rand -base64 32)" >> "$S"
printf 'PHONE_FINGERPRINT_KEY=base64:%s\n' "$(openssl rand -base64 32)" >> "$S"
printf 'DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" >> "$S"

cd /opt/barakabozor/repo
BB_COMPOSE_OVERRIDE=docker/backup/compose.local-repo.yaml BB_RELEASE="$(cat /opt/barakabozor/state/release)" \
  docker/backup/restore.sh "$S"
BB_COMPOSE_OVERRIDE=docker/backup/compose.local-repo.yaml BB_RELEASE="$(cat /opt/barakabozor/state/release)" \
  docker/backup/restore.sh "$S" <snapshot id from the list>
```

The first call lists the snapshots; the second restores one. Compare the scratch
database with the live one (the counts agree up to the changes since the snapshot),
and check that the images came back:

```text
SC="env BB_RELEASE=$(cat /opt/barakabozor/state/release) docker compose --env-file $S -f docker/compose.prod.yaml -f docker/backup/compose.local-repo.yaml"
$SC exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select count(*) from users"'
docker/stack.sh exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select count(*) from users"'
$SC exec -T app sh -c 'ls storage/app/public | head'
```

Do not run `create-role.sh` for the scratch stack. Remove it, with its own env
file and nothing else:

```text
$SC down -v
rm -rf /opt/barakabozor/scratch
```

## 9. Step 2: production

Step 2 comes before the Google Play upload of W4-6 (`DL-141` (1)). What changes:

- **The domain.** The Owner's `.uz` domain; `API_HOST`, `PANEL_HOST`, `APP_URL` and
  `CORS_ALLOWED_ORIGINS` change, and Caddy gets new certificates.
- **`APP_ENV=production`.** `LOGIN_CODE_DRIVER=telegram`, `TELEGRAM_GATEWAY_TOKEN`
  set and restricted to the server's address, `LOGIN_CODE_TEST_PHONES` and
  `LOGIN_CODE_TEST_CODE` removed (production refuses them, `BR-ROLE-011`), and the
  reviewer phone and its code set (`DL-105`).
- **Backups away from the server.** `RESTIC_REPOSITORY` an `s3:` or `sftp:`
  address with its keys; `BB_COMPOSE_OVERRIDE` and `BACKUP_LOCAL_REPOSITORY` removed
  (`DL-104` (6)).
- **The checks that need them:** the `409` for a number without Telegram, every
  staff number reaching Telegram, the external check on the server and the
  backups, and Owner question 2 (`DELIVERY_HANDOFF_POINT`).
- **A deploy key, if the repository turns private.** The server clones over HTTPS
  with no credential because the repository is public. Then, as `deploy`:

```text
ssh-keygen -t ed25519 -N '' -C 'barakabozor-deploy' -f ~/.ssh/barakabozor_deploy
cat ~/.ssh/barakabozor_deploy.pub
```

  The Owner adds the printed public key to the repository as a **read-only**
  deploy key (Settings > Deploy keys). Then the clone changes its address and
  `~/.ssh/config` names the key for GitHub:

```text
git -C /opt/barakabozor/repo remote set-url origin git@github.com:Shoxrux2017/baraka-bozor.git
printf 'Host github.com\n  IdentityFile ~/.ssh/barakabozor_deploy\n  IdentitiesOnly yes\n' >> ~/.ssh/config
git -C /opt/barakabozor/repo fetch --tags origin
```
