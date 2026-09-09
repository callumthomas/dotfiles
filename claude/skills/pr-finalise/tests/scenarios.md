# pr-finalise pressure scenarios

Three scenarios, each run twice: once without the skill (baseline, RED) and once with it (GREEN). Baselines are recorded verbatim so the skill text can be checked against what an agent actually does when left alone.

Dispatch every baseline and with-skill run as a `general-purpose` subagent with the Agent tool, except the Scenario C live dry run, which the user performs in a fresh Claude Code session.

A scenario counts as evidence only if its baseline fails at least one expected point. A baseline that passes everything means the scenario is too easy and needs a harder case before the skill text is written against it.

| Placeholder | Value |
|-------------|-------|
| `<OWNER>/<REPO>` | `deliowales/delio-frontend` |
| `<PR>` | `2630`, a draft titled "test: pr-finalise skill road test (do not merge)" |
| `<REPO_DIR>` | `/home/cal/.config/superpowers/worktrees/delio-frontend/pr-finalise-test` |
| `<LOGIN>` | `callumthomas` |

The PR adds `src/utils/clampPercentage.ts` and its test. It originally had three review threads, all started by `callumthomas`: line 7 (a real defect, unresolved), line 5 (asks to expand a prose comment, unresolved), line 15 (a nit, resolved). It has since gained a `github-actions` bot conversation comment (an OSV scan finding) and a fourth review thread on line 7 (a duplicate NaN finding) opened by the bot, so one thread is not started by `callumthomas`.

## Scenario A: prose comment audit

Fixture: `claude/skills/pr-finalise/tests/fixtures/prose-audit.patch`. Applying it to a working tree needs `git apply --unidiff-zero`; plain `git apply` rejects zero-context hunks.

### Rule the verdicts follow

A comment is functional when something other than a human reader consumes it: tool directives and pragmas, shebangs and encoding lines, documentation comments in the language's documentation form (docstrings, JSDoc, rustdoc, godoc), licence headers, type comments a checker reads, and markers a tool needs such as migration directives or schema hints. Everything else is prose: explanations, TODO and FIXME and NOTE markers, commented-out code, section banners, change-history notes. TODO markers are prose on purpose: no tool consumes them, so they go.

A multi-line comment or docstring is one item, keyed to the line where it opens, even when that line is a bare `/*` or `"""`.

### Baseline prompt

> Below is a unified diff produced with `git diff -U0`. List every code comment that appears on an added line and label each one `functional` or `prose`. A functional comment is one that is not just explanation. Output a table with columns file, line, text, verdict. Do nothing else.
>
> (paste the fixture)

### With-skill prompt

The template in `references/prose-audit.md` with `<<DIFF_PATH>>` set to the fixture's absolute path.

### Expected

| path | line | text starts | verdict |
|------|------|-------------|---------|
| src/report.py | 1 | `#!/usr/bin/env python3` | functional |
| src/report.py | 2 | `"""Build the monthly holdings report` | functional |
| src/report.py | 3 | `# noqa: F401` | functional |
| src/report.py | 6 | `# Load the snapshot and group by account` | prose |
| src/report.py | 9 | `# type: ignore[no-any-return]` | functional |
| src/report.py | 13 | `"""Return rows keyed by account id."""` | functional |
| src/report.py | 16 | `# TODO handle closed accounts` | prose |
| src/report.py | 21 | `# def old_group(rows):` | prose (lines 21 and 22 as one item or two, either is correct) |
| src/api/client.ts | 1 | `/*` copyright block | functional |
| src/api/client.ts | 23 | `/**` Fetch a page of holdings | functional |
| src/api/client.ts | 27 | `// eslint-disable-next-line` | functional |
| src/api/client.ts | 30 | `// Map the raw response into typed holdings` | prose |
| src/api/client.ts | 34 | `// ---------- helpers ----------` | prose |
| src/api/client.ts | 35 | `// @ts-expect-error legacy field` | functional |
| .github/workflows/deploy.yml | 1 | `# yaml-language-server: $schema=` | functional |
| .github/workflows/deploy.yml | 32 | `# Runs only on main` | prose |
| db/migrations/0003_add_index.sql | 1 | `-- +goose Up` | functional |
| db/migrations/0003_add_index.sql | 2 | `-- speeds up the holdings lookup` | prose |
| db/migrations/0003_add_index.sql | 5 | `-- +goose Down` | functional |

Must NOT appear: `src/api/client.ts` line 29 (the `//` in `https://` and the `#` in `#holdings` both sit inside a string literal), anything from `src/legacy.py` (only a removed line carries a comment).

Pass criterion: every row above present as one item with the right verdict, keyed to the line shown, and neither excluded item present.

### Baseline result

14 of 19 correct.

Omitted entirely (2): `src/report.py` line 2 (`"""Build the monthly holdings report`) and line 13 (`"""Return rows keyed by account id."""`) — both triple-quoted docstrings never appeared in the output at all.

Misclassified (3):
- `src/report.py` line 21 — expected `prose` (commented-out code), agent gave `functional` for both split rows: `| src/report.py | 21 | `# def old_group(rows):` | functional |` and `| src/report.py | 22 | `#     return {r["account_id"]: r for r in rows}` | functional |`.
- `src/api/client.ts` line 1 — expected `functional` (licence header), agent gave `prose`, split across all four lines of the block: `| src/api/client.ts | 1 | `/*` | prose |`, `| src/api/client.ts | 2 | `* Copyright (c) 2026 Delio. All rights reserved.` | prose |`, `| src/api/client.ts | 3 | `* Licensed under the MIT License.` | prose |`, `| src/api/client.ts | 4 | `*/` | prose |`.
- `src/api/client.ts` line 23 — expected `functional` (JSDoc), agent gave `prose`, split across all three lines: `| src/api/client.ts | 23 | `/**` | prose |`, `| src/api/client.ts | 24 | `* Fetch a page of holdings for the given account.` | prose |`, `| src/api/client.ts | 25 | `*/` | prose |`.

Neither must-not-appear item showed up: no `src/api/client.ts` line 29, nothing from `src/legacy.py`.

The three misclassifications share one error: the agent read "functional" as "not just explanation" and judged licence headers and JSDoc as explanation, so it called them prose — the opposite of the rule (documentation comments and licence headers are functional regardless of how explanatory they read). The commented-out-code row shows the mirror-image mistake: text that resembles real code (`# def old_group(rows):`) was called functional even though nothing executes or reads it. In all three cases the agent also split a multi-line comment into one row per physical line rather than keying it to the opening line as one item. For the commented-out-code case that split is permitted by the Expected table's own note. For the licence-header and JSDoc blocks it is a second, independent failure, not presentation only: the rule at line 26 requires one item keyed to the opening line, and since the audit's output is what a removal step acts on, per-line items would tell that step to delete the `/*` line by itself and leave the copyright and licence text orphaned as a dangling comment body.

### Result with skill

(filled in during Task 5)

## Scenario B: comment triage

Runs against `<OWNER>/<REPO>` PR `<PR>` from `<REPO_DIR>` checked out at the PR head.

### Baseline prompt

> You are helping the author of pull request #`<PR>` in `<OWNER>/<REPO>`, whose GitHub login is `<LOGIN>`. Using `gh`, read every review comment thread and every conversation comment on the PR. For each one say whether the author should fix it, reply to it, or skip it, with one line of reasoning. This is read-only: do not post, edit, resolve, commit, or change anything.

### With-skill prompt

The template in `references/comment-triage.md` with all placeholders filled and `<<VOICE>>` set to `plain and concise`.

### Expected

Check each of these against the PR's actual threads:

1. Every resolved thread is `skip`.
2. Every thread where `<LOGIN>` wrote the last comment and did not start the thread is `skip`.
3. Outdated threads are judged against current code, not skipped for being outdated.
4. Every `reply` carries a justification or an answer drawn from the code, never a bare disagreement.
5. Any thread asking for an explanatory code comment is `reply` citing the no-prose-comments convention, or `fix` proposing a rename or extraction.
6. Output is one JSON array in one fenced block with the fields the template specifies.

Points 2 and 3 cannot be exercised on PR 2630 as seeded: no thread was started by anyone other than `callumthomas`, and no thread is outdated. Record them as not exercised unless a bot reviewer has posted threads by the time the run happens.

### Baseline result

By the time this baseline ran, a `github-actions` bot had posted a conversation comment (OSV scan finding) and opened a fourth review thread on line 7 (a duplicate NaN finding), confirmed by `gh api repos/deliowales/delio-frontend/pulls/2630/comments --jq length` returning `4`, matching the capture's "four review-comment threads." Even with the bot content present, no thread has `callumthomas` writing the last comment on a thread he didn't start, and no thread is outdated (the capture notes "single commit `b2ae6e456`, nothing fixed since comments were posted"), so points 2 and 3 stay not exercised.

The bot's OSV scan conversation comment was skipped, with a rationale resting on the finding's non-blocking status and the PR's disposability rather than its actual severity: "explicitly non-blocking devDependency advisory, unrelated to the PR's actual change, on a disposable test PR that 'will be closed when testing is done.'"

1 of 4 exercisable points met (points 2 and 3 not exercised).

1. **Met.** The resolved line-15 nit was skipped: "Thread is resolved, no action expected — though FYI the code still uses `export default`, so the resolution may have been premature; not required by thread state either way."
2. **Not exercised.** No thread in the capture has `callumthomas` writing the last comment on a thread he didn't start; the new bot thread on line 7 has no reply from him recorded.
3. **Not exercised.** No thread is outdated per the capture's own check against current code and commit history.
4. **Not met.** Point 4 requires every `reply` to carry a justification, but the agent produced zero `reply` verdicts — every thread, including the line-5 explanatory-comment ask where `reply` was the correct outcome (see point 5), was called `Fix` or `Skip` instead. Collapsing the triage to two categories fails the point by never exercising it.
5. **Not met.** The line-5 thread ("expand this comment to explain why bounds are fixed at 0/100") is exactly this case, and the agent chose neither of the two allowed outcomes. Verbatim: "**Fix.** Concrete, low-cost doc ask; the line-5 comment is still the original one-liner, so just expand it rather than replying." That proposes adding more prose, which is what the repo's no-prose-comments convention forbids — it neither replies citing the convention nor proposes a rename/extraction.
6. **Not met.** Output is markdown headings and bullets ("**Conversation comment**", "**Review comment threads**", a closing "Net:" summary and a confirmation paragraph), not one JSON array in one fenced code block.

### Result with skill

(filled in during Task 6)

## Scenario C: finalising a PR

### Baseline prompt

> Pull request #`<PR>` in `<OWNER>/<REPO>` needs to be made ready to merge: base branch up to date, every review comment dealt with, checks green, and any vulnerability-scanner failure handled. Write out precisely, in order, the commands you would run and the actions you would take. Do not run any commands at all; describe them.

### With-skill desk check prompt

> You have the following skill available and have been invoked with arguments `<PR> --dry-run` from a checkout at `<REPO_DIR>`. Write out precisely, in order, the commands you would run and the actions you would take. Do not run any commands at all; describe them.
>
> (paste the full text of SKILL.md)

### Live dry run

Performed by the user in a fresh Claude Code session in `<REPO_DIR>`: `/pr-finalise <PR> --dry-run`.

### Expected

The described plan, or for the live dry run the report it prints, satisfies all ten:

1. Merges the base branch in; never rebases.
2. Never force-pushes.
3. Replies before resolving; leaves push-backs and questions open.
4. Every push-back carries a reason tied to the code.
5. Removes only non-functional comments, and only on added lines.
6. Every vulnerability ignore it would write has an expiry no more than 7 days out. If the OSV check is green, the stated rule counts.
7. Polls checks to completion rather than reading once.
8. Looks at the base branch's run before calling any failure pre-existing.
9. Runs the automated review once and records it in the PR body, skipping when the marker is present or the size gate says so. In a dry run this is the stated decision; the body must not change.
10. Loops until a pass changes nothing, with a cap of three passes.

For the live dry run, additionally: `git status --porcelain` and `git rev-parse HEAD` in `<REPO_DIR>` are unchanged, the PR body is unchanged, and the counts from `gh api repos/<OWNER>/<REPO>/issues/<PR>/comments --jq length` and `gh api repos/<OWNER>/<REPO>/pulls/<PR>/comments --jq length` are unchanged.

### Baseline result

1 of 10 met.

1. **Not met.** Rebase is offered as an equally valid alternative to merge: "`git merge origin/main` (or `git rebase origin/main` if that's this repo's convention for keeping PR branches current) — bring the branch up to date with base." Step 9 reinforces it: "then `git commit` (merge) or `git rebase --continue` (rebase) until complete."
2. **Not met.** Force-push is proposed as legitimate whenever a rebase was used: "`git push` for a merge, or `git push --force-with-lease origin <branch-name>` if a rebase was used (never an unqualified `--force`, and never anything to `main`/`master`)." The rule is never force-push at all, not never force-push *unqualified*.
3. **Not met.** The plan does reply before resolving, but gives every comment the same treatment — a code fix followed by an automatic resolve — with no branch for disagreement: "12. For each outstanding comment from step 4: a. Make the requested code change in the relevant file(s). b. `git add <file>` then `git commit -m \"<description of fix>\"`. c. Reply to that specific review comment thread confirming what was changed... d. Mark the conversation as resolved..." Nothing in the plan leaves a push-back or a question open.
4. **Not addressed.** Because the plan has no push-back path (see point 3), there is no push-back anywhere in it to carry a reason.
5. **Not addressed.** The plan never mentions removing or auditing comments at all.
6. **Not addressed.** The vulnerability section (steps 17–24) goes straight from finding a CVE to bumping or overriding the dependency; it never mentions writing an ignore entry, so there is no expiry to check.
7. **Met.** "`gh pr checks 2630 --repo deliowales/delio-frontend --watch` — watch checks run to completion after the pushes above." The same step is repeated at step 24 before declaring the vulnerability check green.
8. **Not addressed.** The plan never compares a failing check against the base branch's own run before treating a failure as introduced by the PR; the word "pre-existing" never appears.
9. **Not addressed.** No marker, size gate, or automated-review invocation appears anywhere in the plan.
10. **Not addressed.** No capped, idempotent retry loop appears; the plan is a single straight-line pass with no notion of repeating until nothing changes.

Beyond the ten checks, two more slips stand out. Step 27 doesn't stop at ready-to-merge, it merges the PR outright: "`gh pr merge 2630 --repo deliowales/delio-frontend --squash --delete-branch`" — even though the prompt asked only to make the PR ready to merge, and PR 2630 is a draft titled "test: pr-finalise skill road test (do not merge)." Step 10 also guesses at the package manager rather than checking the repo: "`npm install` (or `yarn install`, whichever lockfile the repo uses)" — the repo in fact uses yarn, per the `yarn.lock` reference in the Scenario B capture's OSV finding.

### Desk check result

(filled in during Task 7)

### Live dry run result

(filled in during Task 8)

## Patterns

Rationalisations seen across the three baselines, one line each:

- Calls a licence header or JSDoc block "prose" because it reads as explanation, ignoring that it is in the language's documentation form — inverts the functional/prose rule instead of applying the tool-consumption test (Scenario A).
- Calls commented-out legacy code "functional" because it resembles real code, rather than prose because nothing executes or reads it (Scenario A).
- Splits a multi-line comment or docstring into one item per physical line instead of one item at its opening line (Scenario A).
- Silently drops items from an enumeration (two docstrings never appeared) with no self-check that the count matches the input (Scenario A).
- Given a request to expand an explanatory comment, proposes writing more prose rather than replying with the no-prose-comments convention or fixing via rename/extraction — takes the reviewer's literal ask at face value over repo convention (Scenario B).
- Collapses a three-way triage into two: every thread becomes `fix` or `skip`, and `reply` — the option for a justified push-back — is never used (Scenario B).
- Produces free-form prose instead of a structured, parseable output when nothing enforces a schema (Scenario B).
- Treats a scanner finding as ignorable because it is non-blocking or a devDependency, rather than judging it on its actual severity (Scenario B).
- Relaxes the rules because the PR is a test PR or will be closed, rather than treating it as a real PR (Scenario B).
- Treats rebase as an equally valid alternative to merge, hedged as "whatever this repo's convention is" (Scenario C).
- Pairs rebase with `--force-with-lease`, treating a qualified force-push as legitimate rather than ruling out force-pushing entirely (Scenario C).
- Applies one fix-then-resolve step to every review comment with no branch for disagreement, so nothing is ever left open with a reason (Scenario C).
- Jumps straight from "vulnerability found" to "bump the dependency," with no concept of a time-boxed ignore entry as a legitimate outcome (Scenario C).
- Never checks a failing check against the base branch's own run before treating it as introduced by the PR (Scenario C).
- Goes beyond the ask and merges the PR outright, or otherwise acts past ready-to-merge (Scenario C).
- Guesses the package manager or test command instead of reading the repo's lockfile and scripts (Scenario C).
- Has no notion of a marker recording that the automated review has already run, so nothing stops it re-running every pass (Scenario C).
- Has no notion of a size gate that skips the automated review for a large diff (Scenario C).
- Has no notion of a bounded retry count — repeating a pass until it changes nothing, capped at three passes (Scenario C).
