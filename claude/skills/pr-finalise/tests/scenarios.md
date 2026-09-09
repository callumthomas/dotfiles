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

The PR adds `src/utils/clampPercentage.ts` and its test. It has three review threads, all started by `callumthomas`: line 7 (a real defect, unresolved), line 5 (asks to expand a prose comment, unresolved), line 15 (a nit, resolved).

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

(filled in during Task 2)

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

(filled in during Task 2)

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

(filled in during Task 2)

### Desk check result

(filled in during Task 7)

### Live dry run result

(filled in during Task 8)
