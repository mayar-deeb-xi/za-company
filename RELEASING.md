# Branches, versions and releases

## The two branches

- **`develop`** is where work happens. Commit and push here day to day.
- **`main`** gets a feature when it is finished: merge `develop` into it.

```sh
git switch main
git pull
git merge develop
git push
git switch develop
```

You can merge into `main` as often as you like. A merge is not a release.

## What a release is

A release is **the `VERSION` file changing on `main`**, and nothing else.
When a push to `main` changes `VERSION`, `.github/workflows/release.yml`:

1. checks the number,
2. tags that commit `v<number>` (for example `v0.2.0`),
3. publishes it on the repository's **Releases** page, with every commit
   since the previous release as the notes.

Pushes that leave `VERSION` alone never trigger it.

## Making a release

1. Change the number in `VERSION`. You can do this on `develop` and merge it,
   or commit it straight on `main`.
2. Push `main`.
3. Within a minute or so, the new release appears under **Releases** on
   GitHub. The **Actions** tab shows the run.

The number is `MAJOR.MINOR.PATCH`, written without a `v`:

| Change | Example |
|---|---|
| a fix, nothing new | `0.1.0` -> `0.1.1` |
| a new feature or floor | `0.1.1` -> `0.2.0` |
| the finished game, or anything that breaks old saves | `0.9.0` -> `1.0.0` |
| a test build ahead of a release | `1.0.0-beta.1` (marked *pre-release*) |

The workflow refuses a number lower than the latest release, because that is
a typo rather than a release. Re-using a number that is already released does
nothing.

## If something goes wrong

- **The run failed**: open it in the Actions tab. The error names the problem
  (usually the format of `VERSION`). Fix it and push again.
- **Run it again by hand**: Actions -> Release -> *Run workflow* on `main`.
  If the version is already released, it stops without doing anything.
- **Undo a release**: delete it on the Releases page, then delete its tag
  (`git push origin :refs/tags/v0.2.0`).
