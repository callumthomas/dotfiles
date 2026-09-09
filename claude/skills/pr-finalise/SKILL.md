---
name: pr-finalise
description: Use when an open pull request has its code written and needs taking to mergeable, or when asked to finalise a PR, address its review comments, clear failing checks, or deal with a vulnerability scanner blocking the merge.
argument-hint: "[<number>|<url>] [--dry-run] [--ignore-days <n>]"
disable-model-invocation: true
allowed-tools: Agent, Skill, Read, Edit, Write, Glob, Grep, Bash
---

# pr-finalise

Take an open pull request from "code written" to "ready to merge", then stop. The run ends when a full pass changes nothing.

**Core principle: all state lives on GitHub, and every pass is safe to repeat.** The body marker, thread resolution, and who wrote each thread's last comment are the only memory. Nothing is stored locally.

**Violating the letter of a rule below is violating its spirit.** Each rule exists because a capable agent broke it while believing its case was different.

Arguments: `$ARGUMENTS`. Empty means the PR for the current branch. Otherwise a number or a PR URL, plus optional `--dry-run` and `--ignore-days <n>`. Without `--ignore-days`, vulnerability ignores expire in 7 days.

`--dry-run` makes exactly one pass: preflight, triage, the prose audit, vulnerability listing, the review-gate decision, and one read of check status, then the report. It writes nothing inside the checkout, runs no git command that moves HEAD, the index, or a local branch, posts nothing, dispatches no review, and leaves the marker alone. A checkout or fast-forward moves HEAD: in a dry run, a preflight step 4 or 5 that would need one stops with the reason instead.

Recipes for every gh, REST, GraphQL, and git command named below are in `references/github-api.md` in this skill's directory. Read it once at the start of the run.

## Rules that do not bend

| Rule | Not even when |
|------|---------------|
| Hydrate by merging the base branch in. Never rebase. Never force-push, `--force-with-lease` included. | "history would be cleaner", "they're only my commits", "that's this repo's convention" |
| Every push-back reply gives a reason tied to the code. | "the comment is obviously wrong" |
| A thread is resolved only after a reply saying what was done, and never after a push-back or an unanswered question. | "the fix is visible in the diff", "resolving keeps the PR tidy" |
| Triage has three outcomes: `fix`, `reply`, `skip`. Each item is acted on under the `class` and `rule` the subagent returned; none is reclassified, dropped, or downgraded from a reply to a fix. | "it's quicker to just change it", "not worth arguing", "the reviewer probably meant something else" |
| A subagent's result is the first fenced JSON block in its reply, parsed. Narration outside it is never acted on. Every item in the array reaches the report. | "the summary says the same thing", "that item was obviously nothing" |
| Prose comments are removed from added lines only. Comments on unchanged lines stay, even in files the PR touches. | "I'm already in the file" |
| Audit verdicts stand, and form decides them, not content: a docstring, JSDoc, PHPDoc block, or licence header stays however plainly it reads; commented-out code goes however much it looks like code. A block comment goes whole, `line` through `end_line`. | "it's only explanation", "someone might need that code later" |
| No prose comment is ever added, including in scanner config, in tests, or because a reviewer asked for one. | "the ignore needs explaining", "it's a concrete, low-cost ask" |
| Every live scanner finding is worked through `references/vuln-remediation.md`, fix route first, whether it arrives as a failing OSV check, as the scanner's comment on a passing one, or as a triage `fix` item. Severity labels, `non-blocking`, devDependency status, and the finding predating this PR change nothing. | "it's a dev dependency", "it's marked non-blocking", "this PR didn't touch that package", "the check is green" |
| Every vulnerability ignore this run writes carries `ignoreUntil` at most 7 days out unless `--ignore-days` says otherwise. An ignore entry this run did not write is never edited, except the single expired entry whose expiry caused this failure. A bump whose test failure is not a quick fix is reverted and the finding takes the ignore route; a red suite is never committed. | "no fix will ever ship", "the tests were probably flaky", "the old entry just needs a date", "a fix exists so no ignore is needed", "the migration belongs in a separate PR", "90 days matches the review cadence" |
| Checks are polled to completion. A failure is called pre-existing only with the base branch's run of the same workflow in front of you. | "it passed last time", "that job is always flaky" |
| pr-review runs at most once per PR. The marker and the size gate decide, not judgement. | "the diff changed a lot since", "it's expensive", "it's too small to bother" |
| The package manager and test command are the ones preflight detected from the manifests and lockfiles. | "npm is the default", "it's probably yarn" |
| A draft, a test PR, or a PR due to be closed is worked exactly like any other. | "it's only a test", "it'll be closed anyway" |
| The run ends at ready-to-merge. Never merge, approve, mark ready for review, request a review, or close the PR. | "everything is green", "they'll want it merged anyway" |
| Passes repeat until one changes nothing, capped at three. Never a fourth pass; never finished after a single straight-line pass without the exit conditions checked. | "one more pass would finish it", "the first pass looked complete" |
| Nothing is committed to the base branch. All commits land on the PR's head branch. | never |
| Stage explicitly with `git add -- <paths>`. Never `git add -A`, `git add .`, or `git commit -a`. | "the tree was clean a moment ago", "everything in there is mine" |
| Every commit made this run is pushed (`git push origin <head>`, never force) before a reply cites it and before any report prints. A `Fixed in <sha>` reply and a resolved thread never refer to a commit that is not on the remote. | "step 6 pushes anyway", "the run is stopping, nothing more to do" |

## Flow

```dot
digraph pr_finalise {
    preflight [label="Preflight", shape=box];
    hydrate [label="1 Hydrate", shape=box];
    comments [label="2 Comments: triage, fix or reply, resolve", shape=box];
    vulns [label="3 Vulnerabilities: fix or time-boxed ignore", shape=box];
    prose [label="4 Prose comments: audit and remove", shape=box];
    review [label="5 Review once, write marker", shape=box];
    push [label="6 Push, poll checks, fix failures", shape=box];
    exit_check [label="No commits this pass, no fix/reply items, checks green, marker present, base unchanged?", shape=diamond];
    more_passes [label="Fewer than 3 passes done?", shape=diamond];
    report [label="Report", shape=doublecircle];

    preflight -> hydrate -> comments -> vulns -> prose -> review -> push -> exit_check;
    exit_check -> report [label="yes"];
    exit_check -> more_passes [label="no"];
    more_passes -> hydrate [label="yes"];
    more_passes -> report [label="no: stop, say why"];
}
```

Any stop condition anywhere pushes committed work, then goes straight to Report with the reason.

## Preflight

Stop with a one-line reason on any failure.

1. Resolve the PR with `gh pr view`. Stop if state is not OPEN or `isCrossRepository` is true.
2. Confirm the working directory is a checkout of the PR's repo.
3. Confirm `git status --porcelain` is empty.
4. Confirm the current branch is the head branch. If not, check it out.
5. `git fetch origin`. If behind `origin/<head>`, `git merge --ff-only origin/<head>`. Stop if diverged.
6. Record our login with `gh api user`.
7. Read the marker from the body. Absent means the review has not run.
8. Detect OSV: grep `.github/workflows/*.yml` and `*.yaml` for `osv-scanner`. If the match is a `uses:` reference to another repository's workflow, read that workflow with `gh api -H "Accept: application/vnd.github.raw" repos/<o>/<r>/contents/<path>?ref=<ref>` and take the pinned version and any `--config` from there. Record the workflow name as the calling workflow's `name:` value, which is what `gh pr checks --json workflow` returns, not the filename; the pinned version; and the config path: an explicit `--config` argument if the scan passes one, else `osv-scanner.toml` in the directory of each scanned lockfile. Absent means step 3 is skipped every pass.
9. Detect the package manager and test command from what is present. `composer.json` with `composer.lock`: composer, tests via `vendor/bin/phpunit` or `vendor/bin/pest`, whichever exists, or `composer test` if the script exists. `package.json`: npm, yarn, or pnpm by lockfile (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`), tests via the manifest's `test` script. `pyproject.toml` with `uv.lock`: uv; with `poetry.lock`: poetry; otherwise pip with `requirements*.txt`; tests via pytest. `go.mod`: `go test ./...`. `Cargo.toml`: `cargo test`. With several manifests, run the tests of the one whose files the change touched.
10. Resolve the reply voice: `./.claude/pr-review-voice.md`, then `~/.claude/pr-review-voice.md`, else plain and concise.

## Pass

Run steps 1 to 6 in order. Count commits made. In `--dry-run`, steps 1, 3, 5, and 6 only report what they would do, and steps 2 and 4 stop after their subagent returns.

### 1 Hydrate

`git fetch origin`, record `git rev-parse HEAD` and `git rev-parse origin/<base>`, then `git merge origin/<base>`. On conflict, list conflicted files. If every one is a lockfile, take the base's lockfile, regenerate it from the merged manifest without upgrading, and finish the merge. If the regeneration fails, `git merge --abort` and stop. Any other conflicted file: `git merge --abort`, stop, report the list.

### 2 Comments

Fill `references/comment-triage.md` with owner, repo, PR, base, our login, head SHA, and the voice. `<<HEAD_SHA>>` is `git rev-parse HEAD` taken at dispatch, the local head with the base merged in, not `headRefOid`. Dispatch it as a `general-purpose` subagent from the checkout. Parse the first fenced JSON block in its reply and ignore text outside it; an empty array means nothing to do. Each item carries `class` and `rule`. Branch on `rule`, never on `reason`. An outdated thread's `location` is `<path>:<originalLine>`; find where that code lives now with `git log -S` or `git blame`.

Run the pending-review guard once per pass, before the first reply attempt.

| class | rule | Action |
|-------|------|--------|
| `fix` | any | Make the change, run the relevant tests, stage with `git add -- <paths>`, commit as `fix: <one line>` (one commit per thread; threads describing the same defect may share one), reply `Fixed in <short sha>: <one line>` with that same line, then resolve. If a sibling item's commit already made the change, reply with that sha and resolve; do not commit again. Conversation comments and review bodies get the reply only. |
| `fix` | any, when the ask is a dependency version or a vulnerability | Work the change through `references/vuln-remediation.md` in its order: fix route, then its micro-framework section, then override, then revert and ignore. Stage with `git add -- <paths>`, commit as `deps: <one line>`, and only then reply and resolve as above. Step 3 reaches the same file, so the two paths cannot disagree. |
| `reply` | 4 | Post the proposal, then resolve: a commit superseded it. |
| `reply` | 6, 7, 8 | Post the proposal. Leave the thread open. |
| `skip` | 2 | If the thread is still open and our last comment reads `Fixed in <sha>`, resolve it; nothing further is owed. Otherwise nothing. |
| `skip` | 1, 1b | Nothing. |

A class and rule pair not in this table is reported as an unactioned item, verbatim, and the pass continues.

Reply mechanics by kind: threads use the replies endpoint with `reply_to`; conversation comments and review bodies get a new top-level comment opening with a quote of the comment's first heading line. Before any reply, run the dedup check for its kind and skip if we already replied. A thread holding a single comment is unanswered even when that comment is ours: pr-review opened it, so the dedup check does not fire.

If this step made commits, `git push origin <head>` before leaving it, never with force. The reply `Fixed in <sha>` and the resolved thread must never refer to a commit that is not on the remote.

### 3 Vulnerabilities

Skip if preflight found no OSV workflow. Otherwise read the OSV check's bucket with `gh pr checks --json` and read the scanner's PR comment. Work `references/vuln-remediation.md` when the OSV check is failing, or when the scanner's PR comment reports a finding live at HEAD and uncovered by an ignore entry. A passing check with no live finding: skip. A pending check with no live finding: skip this pass. For each finding, fix route first, ignore route only when the fix route fails, stage with `git add -- <paths>`, commit per finding. A finding whose package is already at or above the fixed version at HEAD is verified, not worked: report it as already fixed. A finding reached through `@deliowales/micro-*` or `@deliowales/lib-*` takes that file's micro-framework section before any override or ignore. A finding step 2 already worked this pass is reported with its commit, not worked again.

### 4 Prose comments

Write `git diff -U0 origin/<base>...HEAD` to a directory from `mktemp -d`, fill `references/prose-audit.md` with the path, dispatch it as a `general-purpose` subagent. Parse the first fenced JSON block in its reply and ignore text outside it. For every item marked `prose`, remove lines `line` through `end_line`, highest line first within each file. Where a removed comment carried meaning the code lacks, rename, extract, or restructure instead of keeping it. Run the tests preflight detected; a failure means the tree is not safe to commit: `git restore --source=HEAD --worktree --` every file this step touched, and stop. Stage the touched files with `git add -- <paths>` and commit once: `chore: remove non-functional comments`. Touch nothing on unchanged lines.

### 5 Review, once

Marker present: skip. Otherwise compute the size gate. Fewer than 30 changed lines, or every changed file a manifest or lockfile: write the marker as `review=skipped:<reason>` and skip. Otherwise `git push origin <head>`, write the marker as `review=<head sha>`, then invoke the `pr-review:pr-review` skill with the PR number and no other arguments. The marker goes first so an interrupted review is never re-run. Its comments are triaged by step 2 on the next pass.

### 6 Push and wait

`git push origin <head>`. A rejected push means `git fetch origin`, then `git merge origin/<head>`, never force, then push again; a second rejection stops the run. If nothing was pushed this pass and every check has already completed, skip the wait. Otherwise poll: `gh pr checks <n> --json name,state,bucket,link,workflow` every 30 seconds, inside an explicit budget of 20 minutes per wait, until no bucket is `pending`. A wait cut off by the budget or by the tool's timeout is re-read with the same command, never re-pushed. "no checks reported" is retried for 60 seconds after a push; if it persists, print it as its own report line and count zero checks as green for the exit condition. Then classify by bucket:

- OSV workflow failing: step 3 handles it next pass.
- Test, lint, type, or build failure: read the log, fix, stage with `git add -- <paths>`, commit, push, poll again. At most two fix attempts per check per pass; a third failure stops the run with the log excerpt.
- Infrastructure failure (runner lost, timeout, network, cancelled): check the base branch's latest run of the same workflow. If it is green and the log shows an infrastructure error, `gh run rerun --failed` once. A second failure of that run is real: stop with the log excerpt.

## Exit

Success after a pass when all hold: no commits this pass (`git rev-list --count <recorded HEAD>..HEAD` is 0); triage returned no `fix` or `reply` items; every check is `pass` or `skipping`, or zero checks are reported after the 60-second retry and the report says so; the marker is present; `git fetch origin` shows `origin/<base>` still at the SHA recorded in this pass's step 1. Otherwise run another pass, up to three.

Stop early on: a non-lockfile merge conflict; a lockfile regeneration that fails during hydration; a fork PR; a dirty tree or diverged branch; a push rejected twice; tests failing after a prose removal; an infrastructure failure that fails again after one rerun; a test, lint, type, or build check still failing after two fix attempts in one pass; a vuln bump that breaks tests where the ignore route is also unavailable; pr-review failing to run; three passes exhausted. Every stop-early path pushes committed work with `git push origin <head>` before printing the report.

## Report

Print at the end of every run, dry or real:

- Threads: table of `location`, `class`, `rule`, `action taken`, `commit`; an item outside the step 2 table appears with `unactioned`.
- Vulnerabilities: table of `id`, `package`, `fixed to`, `already fixed`, or `ignored until`, `reason`.
- Prose comments removed: `path:line` list.
- Review: ran at `<sha>`, or skipped with reason, or already present from `<date>`.
- Commits: every commit made this run and its push state, on the remote or not.
- Checks: name and final bucket for each, or the "no checks reported" line.
- Mergeability: `mergeable` and `mergeStateStatus` from `gh pr view --json mergeable,mergeStateStatus`, read at report time.
- Left for you: push-backs awaiting a reviewer, unactioned items, any stop reason, ignores with their expiry dates, and the reminder that re-requesting review happens in Slack.

## Red flags

Stop and re-read the rules table if you notice yourself:

- Typing `rebase`, `--force`, or `--force-with-lease`.
- Typing `gh pr merge`, `gh pr ready`, `gh pr review`, or `gh pr close`.
- Typing `npm install` before reading the lockfile.
- Resolving a thread you have not replied to.
- Writing a reply that says no without a because.
- Changing a triage item's class, or acting on fewer items than the array holds.
- Reading a subagent's narration instead of parsing its JSON block.
- Editing a comment on a line the PR did not add, or deleting one physical line of a block comment.
- Calling a docstring or licence header prose, or commented-out code functional.
- Adding a comment to explain code you just changed, or because a reviewer asked for one.
- Skipping a finding because it is `non-blocking`, a devDependency, older than the PR, on a test PR, or under a passing check, or because the check would pass with it still listed.
- Writing an ignore entry with no `ignoreUntil`, editing an ignore entry this run did not write, or committing a bump with failing tests.
- Leaving a finding to a ticket or a separate PR instead of a commit or an ignore, or dating an ignore past the 7-day rule because a review cadence says so.
- Typing `git add -A`, `git add .`, or `git commit -a`.
- Printing a report, or replying `Fixed in`, while a commit made this run is not on the remote.
- Reading check status once instead of polling to completion, or pushing again because a wait timed out.
- Calling a failure pre-existing without the base branch's run open.
- Deciding the review "isn't needed this time" when the marker is absent and the gate is clear.
- Starting a fourth pass, or reporting done after one pass without the exit conditions in hand.
- Storing progress anywhere but GitHub.
