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

## After the user merges a pull request

1. `git fetch --prune origin && git checkout main && git pull --ff-only origin main`
2. Delete the feature branch on GitHub and locally: `git push origin --delete <branch>` and
   `git branch -d <branch>`.

Done when `git branch -a` lists only `main` and `origin/main`. Then stop: the next issue or task starts
only when the user asks for it, even one already named as coming next.

## Pull requests

- Title: the first commit's summary line.
- Body: the issue link on the first line, then a `## What changed` section of bullets. When the issue
  has steps left to do by hand (App Store Connect, TestFlight), add `## Still to do by hand`; when the work
  was checked by running something, add `## Checked`.
- The issue link is `Closes #<issue>` only when every acceptance criterion box in the issue is ticked
  before the pull request is opened (see Issues). Otherwise it is `Refs #<issue>`, in the pull request and
  in its commits.
- `#<issue>` appears only right after `Refs` or `Closes`. In a sentence, write the issue as "issue 17",
  with no `#`: GitHub closes an issue when close, fix or resolve, in any tense, comes before its `#N` in a
  merged commit or pull request, so "merging #19 closed #17" closed issue 17 early.

## Issues

An issue closes only with every acceptance criterion box ticked. Merging a `Closes` pull request closes the
issue at once, so the boxes are ticked first:

1. Before opening the pull request, verify each criterion on the branch: a passing test, a run in the
   Simulator, the changed file.
2. Tick the box of each verified criterion in the issue body.
3. A criterion that waits on a step by hand or on the merge itself stays unticked, and the pull request
   says `Refs`. Tick it once it is done, and close the issue when the last box is ticked.

Done when the pull request is open and every criterion its work verified is ticked in the issue.

## Where things are

- [GLOSSARY.md](GLOSSARY.md): the glossary. Code, tests, docs and commit messages use its words.
- [README.md](README.md): build, run, test and the release flow.
- [docs/orientation.md](docs/orientation.md): project layout and the household core seam.
- [docs/xcode-cloud.md](docs/xcode-cloud.md): the Xcode Cloud workflows; read before changing build settings,
  the scheme, the app icon or anything else that decides what is uploaded to TestFlight.
- Specs and tickets are GitHub issues in this repo.
