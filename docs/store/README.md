# Google Play store material

What the Android release needs besides the code (`DL-104` (13), `DL-116`). The Owner submits it in Play Console; the agent keeps it current. Owner-facing files are in Russian.

| File | What it holds |
|---|---|
| `play-console.ru.md` | The Owner's steps in order: creating the app, App content, the listing, closed testing, the key fingerprints in Google Cloud, applying for production |
| `listing.md` | The listing texts, the graphics and the store settings |
| `data-safety.ru.md` | The Data safety answers, each with its source in the code |
| `content-rating.ru.md` | The content-rating questionnaire answers |
| `graphics/` | The store icon (`play-icon-512.png`, from `tasks/scripts/build_icons.py`) and the feature graphic (`feature-graphic-1024x500.png`, rendered from `feature-graphic.html` with headless Chrome at 1024×500); `source/` holds the Owner's icon artwork, unchanged (`DL-116` (11)) |

## Signing

The release is signed with the upload key named by `frontend/android/key.properties` (gitignored; the keys are listed in `frontend/android/key.properties.example`). The keystore is `G:/tools/secrets/barakabozor-upload.jks` on the development machine and in the Owner's own copy: RSA 4096, alias `upload`, valid until 2054. Play App Signing holds the app's key. A release build without a complete `key.properties` fails with the reason; debug, profile, tests and the web build need nothing (`DL-116` (1)).

Fingerprints (public, needed for the API key restrictions):

| Key | SHA-1 |
|---|---|
| Upload | `EB:3F:C7:5D:D3:16:EF:C0:BF:E8:82:E5:1E:7D:5A:81:AD:12:48:EE` |
| Debug (development builds on the agent's machine) | `E2:5B:B5:C4:A6:B1:6F:25:31:37:E9:89:1E:2D:53:64:26:AC:97:0C` |
| Play app signing | shown in Play Console after the first upload |

## Releasing a build

1. In a pull request, raise the build number after `+` in `frontend/pubspec.yaml` (`version: 1.0.0+1` → `1.0.0+2`). Play refuses a version code it has seen (`DL-116` (2)).
2. Merge it, check out `main`, and make sure `frontend/.env.release` holds `BB_API_BASE_URL=https://api.<domain>/api/v1` beside `.env.maps` and `.env.firebase` (all gitignored).
3. Run `powershell -File tasks/scripts/build_release.ps1`. It refuses a modified tree, a version without `+N`, an incomplete `key.properties` or env file, an API address other than `https://<host>/api/v1`, and a bundle not signed with the upload key. It writes `frontend/build/release/barakabozor-<version>-<code>.aab` and a `.txt` with the commit, the version, the bundle's SHA-256 and the signer's fingerprints.
4. Hand the `.aab` to the Owner for the closed track (`play-console.ru.md`, step 5) and keep the `.txt`.

On this machine, set `GRADLE_USER_HOME=G:\tools\gradle-home` and `TEMP`/`TMP` to `G:\tools\tmp` first; the script sets `JAVA_HOME` to Android Studio's JDK when it is unset.

## Checked on the first release build (2026-10-25)

- signed by `CN=BarakaBozor, C=UZ`, the upload key;
- `zipalign -c -P 16` passes (Play's 16 KB page rule);
- `targetSdkVersion` 36, `minSdkVersion` 26;
- no `com.google.android.gms.permission.AD_ID`, so the Advertising ID answer is "No".
