# GitHub Bootstrap — Project Owner Action Required

The repository foundation is prepared locally, but GitHub delivery is not complete.

## Why this file exists

No `Shoxrux2017/baraka-bozor` repository existed when this baseline was prepared, and the connected GitHub integration did not expose repository-creation capability and returned write-access failures. Therefore the Project Owner must create the empty repository and perform the initial push.

## Recommended GitHub repository

```text
Shoxrux2017/baraka-bozor
```

Create it **empty**: do not initialize with README, `.gitignore`, or license because this local baseline already contains the initial commit.

## Push this prepared repository

From the extracted repository directory:

### SSH

```bash
git remote add origin git@github.com:Shoxrux2017/baraka-bozor.git
git push -u origin main
```

### HTTPS

```bash
git remote add origin https://github.com/Shoxrux2017/baraka-bozor.git
git push -u origin main
```

Then verify:

```bash
git fetch origin
git rev-parse main
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Expected:

```text
main SHA == origin/main SHA
ahead/behind = 0 0
working tree clean
```

After that, Stage 0 Closure Review must be re-run before any Stage 1 implementation begins.

## Commit author note

The prepared local baseline uses a generic local bootstrap commit author. If you require your own author identity, amend the local commit **before the first push** using your normal local Git identity. Do not rewrite history after the baseline becomes shared.
