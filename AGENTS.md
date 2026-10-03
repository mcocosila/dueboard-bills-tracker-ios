# Agent instructions

## Start every piece of work on a fresh branch

Keep one pull request open at a time.

0. `gh pr list --author @me --state open`. If a pull request is open, ask the user whether the new work goes
   on its branch or waits until it is merged; either way, no new branch.
1. `git fetch origin && git checkout main && git pull --ff-only origin main`
2. `git checkout -b <issue number>-<kebab title>`, e.g. `17-xcode-cloud`. Work with no issue drops the
   number: `agents-md`.
3. Commit on that branch. When a skill says to commit to the current branch, this branch is the one.
4. Push the branch and open a pull request against `main`. `main` changes only by merging a pull request.

Done when the pull request is open and `main` matches `origin/main`.

If commits landed on the wrong branch, cut the feature branch where they are, reset that branch to
`origin/<branch>`, and carry on from the feature branch.

## Pull requests

- Title: the first commit's summary line.
- Body: `Closes #<issue>` on the first line, then a `## What changed` section of bullets. When the issue
  has steps left to do by hand (App Store Connect, TestFlight), add `## Still to do by hand`; when the work
  was checked by running something, add `## Checked`.

## Where things are

- [CONTEXT.md](CONTEXT.md): the glossary. Code, tests, docs and commit messages use its words.
- [README.md](README.md): build, run, test and the release flow.
- [docs/orientation.md](docs/orientation.md): project layout and the household core seam.
- Specs and tickets are GitHub issues in this repo.
