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

19 of 19 correct on the first run of the template written in Task 5, and 19 of 19 again on a second, independent run of the same template. No refinement (Step 3) was needed for this fixture at that point; the generalisation fixture below later forced one, recorded under "REFACTOR: the adjacent-directive merge bug".

**Run 1.** Every row in the Expected table appeared, keyed to the correct line, with the correct verdict, as a single item — including both Python docstrings the baseline omitted entirely (`src/report.py` line 2, `"""Build the monthly holdings report...`, and line 13, `"""Return rows keyed by account id."""`, both `functional`), the commented-out block at line 21 (`prose`, reported as one item covering both physical lines, not split), and the licence header (`src/api/client.ts` line 1, reason given: "licence/copyright header block") and the JSDoc block (line 23, reason given: "JSDoc documentation comment"), both correctly `functional` and each a single item keyed to its bare opening delimiter (`/*`, `/**`) rather than split across the block's physical lines. Neither must-not-appear item (`src/api/client.ts` line 29, anything from `src/legacy.py`) was present. Output was a single well-formed JSON array in one fenced block, nothing else.

**Run 2 (confirmation).** Identical outcome: the same 19 items, same lines, same verdicts, still one item per multi-line block. The commented-out block's reason was explicit about the merge: "commented-out code block (two lines, one item)." The licence and JSDoc blocks again stayed single items at their opening `/*` and `/**` lines.

**Baseline-to-skill comparison (RED to GREEN).** The baseline scored 14 of 19, missing exactly the five things the template's Task-5 additions targeted: both docstrings omitted entirely; the commented-out block called `functional` instead of `prose`; the licence header and JSDoc block called `prose` instead of `functional`; and all three multi-line items (the commented-out block, the licence header, the JSDoc block) split into one row per physical line instead of one item at the opening line. All five failure modes are corrected in both skill runs, with no new misses introduced — the explicit "documentation form, not content" clause for docstrings/JSDoc/licence headers, the worked four-line licence-block example showing one item at a bare `/*`, the docstring-hunting instruction for `def`/`class` lines, and the pre-output completeness self-check (count opening lines found vs. items output) together closed the gap on the first attempt, so Step 3 (REFACTOR) was not exercised by this fixture. The generalisation fixture exercised it (see below).

### Generalisation fixture

Fixture: `claude/skills/pr-finalise/tests/fixtures/prose-audit-generalise.patch`, a `git diff -U0` over 12 files (Go, Rust, Dockerfile, JSX, PHP/Laravel model, Blade template, Terraform, Helm `.tpl`, Less, Markdown, shell, and a removed-only Python hunk), 97 insertions, 3 deletions.

The fixture is calibrated to the Delio services stack under `~/dev/denv/services` (PHP/Laravel, TypeScript, Less, Python, Terraform, Go, Rust, Helm, Dockerfile, shell), not to this dotfiles repo: that stack is the audit's real deployment target, so its comment conventions — PHPDoc, Blade `{{-- --}}`, Helm `{{/* */}}`, phpcs/tflint/stylelint suppression directives — need direct fixture coverage rather than being inferred from a generic or dotfiles-flavoured language mix.

#### Expected

| path | line | end_line | text starts | verdict |
|------|------|----------|-------------|---------|
| cmd/report/main.go | 13 | 13 | `// FetchHoldings returns the holdings` | functional (godoc) |
| cmd/report/main.go | 15 | 15 | `// Retry once because the upstream API` | prose |
| src/lib.rs | 1 | 1 | `//! Holdings aggregation helpers.` | functional |
| src/lib.rs | 3 | 3 | `/// Sums the holdings for one account.` | functional |
| src/lib.rs | 5 | 5 | `// TODO handle negative balances` | prose |
| Dockerfile | 1 | 1 | `# syntax=docker/dockerfile:1` | functional |
| Dockerfile | 3 | 3 | `# Install deps before copying source` | prose |
| web/src/HoldingsPanel.jsx | 19 | 19 | `// eslint-disable-next-line react-hooks/exhaustive-deps` | functional |
| web/src/HoldingsPanel.jsx | 24 | 24 | `{/* Skeleton keeps the layout from jumping` | prose |
| app/Models/Holding.php | 9 | 13 | `/**` PHPDoc block with `@property` | functional |
| app/Models/Holding.php | 17 | 17 | `// phpcs:ignore Generic.Files.LineLength.TooLong` | functional, own item |
| app/Models/Holding.php | 18 | 18 | `// The scope excludes accounts closed before` | prose, own item |
| app/Models/Holding.php | 24 | 24 | `/** @var array<int, string> */` | functional |
| app/Models/Holding.php | 27 | 28 | `// protected $casts = ` commented-out code | prose (one item with `end_line` 28, or two, either correct) |
| resources/views/holdings/index.blade.php | 3 | 3 | `{{-- Reviewers: the table below mirrors` | prose |
| infra/terraform/holdings.tf | 1 | 1 | `# tflint-ignore: terraform_required_providers` | functional |
| infra/terraform/holdings.tf | 6 | 6 | `# Bucket keeps thirty days of report snapshots` | prose |
| helm/holdings/templates/_helpers.tpl | 1 | 1 | `{{/* Expand the chart name, truncated` | prose |
| web/src/styles/panel.less | 1 | 1 | `// stylelint-disable selector-max-id` | functional |
| web/src/styles/panel.less | 3 | 3 | `/* Padding matches the card grid` | prose |
| docs/runbook.md | 41 | 41 | `<!-- Reviewers: this section duplicates` | prose |
| scripts/deploy.sh | 1 | 1 | `#!/usr/bin/env bash` | functional |

Must NOT appear: `app/Models/Holding.php` line 14 (`#[\AllowDynamicProperties]`, a PHP attribute), `resources/views/holdings/index.blade.php` line 7 (`{{ $holding->account_id }}`, a Blade echo), `scripts/deploy.sh` lines 3 and 4 (`#` inside strings), `web/src/styles/panel.less` line 2 (`#holdings-panel`, a Less ID selector), anything from `src/legacy_removed.py` (only a removed hunk).

Every `end_line` equals `line` in this fixture except `app/Models/Holding.php` line 9 (PHPDoc block, `end_line` 13) and line 27 (commented-out run, `end_line` 28 if reported as one item). In Scenario A, `src/api/client.ts` line 1 (licence block, `end_line` 4) and line 23 (JSDoc block, `end_line` 25) carry an `end_line` greater than `line`; the two `src/report.py` docstrings are single physical lines, so their `end_line` equals `line`.

#### REFACTOR: the adjacent-directive merge bug

The template committed in Task 5 grouped "a run of consecutive `#`/`--`/`//` lines with no blank or non-comment line between them" into one item regardless of content. Run against the reviewer's draft of this fixture — which at that point used a Ruby model rather than the PHP/Laravel one now committed — that rule merged the Ruby file's line 1 (`# frozen_string_literal: true`) and line 2 (`# rubocop:disable Metrics/ClassLength`) into a single item, rationalised verbatim as "consecutive magic comments ... merged as one block" and "both are functional anyway, so no verdict conflict." Both lines happened to carry the same verdict there, but the same rule would have merged a directive with a following *explanatory* comment — the real-world shape it was tested against was `// eslint-disable-next-line ...` followed by `// because the dep array is intentional` — silently landing one verdict on both lines and pointing a downstream removal step at the wrong line whenever the merged verdict was `prose`. Ruby was subsequently dropped from the audit's target languages (the real target is the Delio services stack, which carries no Ruby), and the committed fixture now guards the same adjacent-directive-then-explanation shape with a PHP case instead, at `app/Models/Holding.php` lines 17 (`// phpcs:ignore Generic.Files.LineLength.TooLong`) and 18 (`// The scope excludes accounts closed before the 2020 migration.`), which must land as two separate items with different verdicts.

Fix: the one-item merge is now restricted to (a) delimited blocks opening with `/*`, `/**`, `"""`, `'''`, `<!--`, `{/*`, `{{--`, or `{{/*`, spanning to their closing delimiter, and (b) runs of consecutive single-line comments where every line in the run is commented-out code. Every other single-line comment — including two adjacent directives, or a directive followed by an explanation — is its own item with its own line, `end_line`, and verdict. The template states explicitly that a directive immediately followed by an explanatory comment is two items, not one, now using the `phpcs:ignore`/explanation and `eslint-disable-next-line`/dep-array examples above. The same pass added an `end_line` field to every output object, and a later pass recalibrated the language table from a generic/dotfiles mix to the Delio services stack — PHP (including `#[...]` attributes and Blade `{{-- --}}`/`{{ $x }}` as non-comment traps), TypeScript/JSX, Less/SCSS/CSS, HCL/Terraform, Go, Rust, Helm/Go `.tpl` templates, SQL, Jenkinsfile, Dockerfile, and shell, plus PHPDoc and the phpcs/phpstan/psalm/stylelint/tflint/checkov/tfsec/hadolint/go: directive families — while trimming duplicated wording elsewhere (the form-vs-content point stated once instead of three times, non-comment tokens like `#pragma` and clippy attributes dropped from the comment list, the self-check's docstring-hunting repetition removed, an untested "type comments" bullet dropped) to hold the body at 996 words.

#### Results with the revised template

Fixture A (`prose-audit.patch`, unchanged, still 19 expected items): 19 of 19 correct on both runs of the recalibrated template — run 1 and a confirmation run 2 — matching verdicts, lines, and `end_line` values throughout, including `end_line` 4 for the licence block and `end_line` 25 for the JSDoc block.

Fixture B (`prose-audit-generalise.patch`, the PHP/Laravel-calibrated version, 22 expected items): 22 of 22 correct on both runs — run 1 and a confirmation run 2. In both runs `app/Models/Holding.php` lines 17 and 18 came back as two separate items with the correct, different verdicts (`functional` then `prose`), confirming the merge fix on the case it was written to guard. The PHPDoc block (lines 9–13) and the inline `/** @var ... */` annotation (line 24) were both correctly `functional`; the Blade comment, Helm `.tpl` comment, and Terraform `tflint-ignore`/explanation pair all landed on their expected verdicts. No must-not-appear item (the PHP attribute, the Blade echo, the two in-string `#` occurrences, the Less ID selector, anything from `src/legacy_removed.py`) showed up in any run.

The Task 5 quality reviewer ran one further uncommitted probe over cases neither fixture covers: a Jenkinsfile (resolved by filename, its `/* */` header one `prose` item spanning lines 2 to 4), a three-line Blade `{{-- --}}` comment (one item, lines 3 to 6), a `.properties` file whose `cache.key=build#20240301` value had to stay excluded, and a multi-line godoc run. 9 of 9 correct, no false positives. Consecutive godoc `//` lines came back as one item per line, which is the accepted cost of the merge fix: functional items are never removed, so splitting them changes nothing downstream.

A live discrepancy was investigated and ruled out as a template defect: across fixture-B runs, the `docs/runbook.md` item's `text` field, and later `app/Models/Holding.php` line 24's `<int, string>` and line 27's `=>`, arrived HTML-escaped (`&lt;`/`&gt;`) in the subagent's returned message. A dedicated diagnostic run had the same subagent write its JSON to a file with its own Write tool instead of only returning it in text; the file on disk held the literal, unescaped bytes (`<!-- ... -->`, confirmed by hex dump). The escaping is introduced downstream of the subagent's own output — in how a subagent's final text is relayed back to the dispatching session — not by the template's instructions or the underlying classification, so no template change was made for it.

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

Six runs. Run 1 used the template as first written and met every exercisable point on the Expected wording but slipped on the template's own output contract; one REFACTOR tightened the output paragraph; run 2 held on everything; run 3 was the confirmation pass and also held; run 4 re-ran after a spec review trimmed two untraced clauses from the template, and also held, but its line-5 reply promised to keep a comment the prose audit removes; a second REFACTOR added one clause to rule 8; run 5 held on everything and the line-5 reply now says the comment is being removed; a spec re-review then scoped that clause to added lines and added a `<<BASE>>` placeholder; run 6 held on every judging point and the line-5 reply still says the comment is being removed, but the response reopened with narration before the fence, the run-1 failure mode; a third REFACTOR named that shape in the output paragraph and made the dispatcher tolerant of text outside the fence; run 7 held on everything; run 8, the confirmation, held on every judging point but reopened with narration before the fence. Eight runs in total, and narration before the fence occurred in three of them (1, 6, 8); the dispatcher tolerance is the safeguard for it. Points 2 and 3 are not exercised in any run because the PR's threads have not changed since the baseline.

**PR state at run time (captured independently before run 1, HEAD `b2ae6e456`).** Four review threads, in GraphQL fetch order: `PRRT_kwDOH9L2T86go3im` (line 7, `callumthomas`, unresolved, not outdated, single comment `3968073026`, the NaN defect); `PRRT_kwDOH9L2T86go3jy` (line 5, `callumthomas`, unresolved, not outdated, single comment `3968073149`, "Could you expand this comment to explain why the bounds are fixed at 0 and 100 rather than configurable?"); `PRRT_kwDOH9L2T86go3lT` (line 15, `callumthomas`, **resolved**, single comment `3968073285`, the named-export nit); `PRRT_kwDOH9L2T86go4_G` (line 7, `github-actions`, unresolved, not outdated, single comment `3968081794`, "Important — unhandled `NaN` input"). One conversation comment, id `5601468962` by `github-actions[bot]`: the OSV scan finding GHSA-82fw-gwwq-j7x9 (CVSS 5.9, labelled non-blocking) against `vitest` 3.2.7 and `@vitest/mocker` 3.2.7, fixed in 4.1.11. At HEAD `package.json` has `"vitest": "^3.2.6"`, `yarn.lock` resolves both packages to 3.2.7, and `osv-scanner.toml` has no entry for the advisory, so the finding stands against current code and the correct class is `fix`. Four review summaries, all with empty bodies, so no `review_body` items. No thread has `callumthomas` as last commenter on a thread someone else started, and nothing is outdated (single commit on the branch), so points 2 and 3 remain not exercised.

**Run 1** (template as first written in Task 6). 4 of 4 exercisable points met on the Expected wording; one deviation from the template's own output contract, treated as a miss and refactored.

1. **Met.** Line-15 thread: `skip`, reason "Rule 1: thread isResolved is true."
2. **Not exercised.** Confirmed against the fetched threads: none has `callumthomas` writing last on a thread started by someone else.
3. **Not exercised.** Every thread has `isOutdated` false.
4. **Met.** Exactly one `reply` (the line-5 thread) and it draws its justification from the code: "the function's name (clampPercentage) and its one-line JSDoc already state the contract is a 0-100 percentage, so the fixed bounds are expressed by naming, not prose." No bare disagreement anywhere.
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "We don't carry non-functional comments explaining rationale in prose here. The name clampPercentage and its JSDoc already say what it does — a percentage is 0 to 100 by definition, so that's not a magic choice that needs explaining, it's the contract the name states. If bounds needed to be configurable we'd rename the function and add min/max parameters, not add a longer comment." No prose is proposed; the alternative offered is a rename plus parameters.
6. **Met on the Expected wording, not on the template's contract.** The fenced block is one JSON array, parses with `jq`, holds 5 items with all 12 fields, in fetch order, with every `id`, `reply_to`, `started_by`, `last_by`, `resolved` and `outdated` value matching the independent capture. But the response opened with two sentences before the fence: "Confirmed the file was added in a single commit at HEAD; nothing supersedes it, so no thread here is outdated. All findings verified directly against current code and manifests." The template said "Nothing before the opening fence", and the agent still narrated its verification there. A second schema slip: the conversation comment's `id` was the number `5601468962`, not a string.

Bot OSV comment, verbatim reason: "Rule 5: package.json pins vitest at \"^3.2.6\", which yarn.lock resolves to 3.2.7 (with @vitest/mocker 3.2.7 pulled in transitively) — still the vulnerable version at HEAD — and GHSA-82fw-gwwq-j7x9 has no entry in osv-scanner.toml's IgnoredVulns, so the 'non-blocking' label and devDependency status don't change the outcome." Class `fix`; proposal names the bump from `^3.2.6` to `^4.1.11` and, if deferred, an `IgnoredVulns` entry with reason and revisit date. Both NaN threads (`callumthomas` and `github-actions`) were `fix` under rule 5 with the same `Number.isNaN` guard, TODO removal, and a `clampPercentage(NaN)` test.

**REFACTOR after run 1.** The output paragraph gained three counters, each traceable to run 1: the first and last characters of the response are the fences; anything verified about the PR as a whole (such as no thread being outdated) belongs in the `reason` field of the items it concerns, never in a sentence before the fence; and `id` is always a string. No judging rule changed, since every verdict was correct.

**Run 2** (template after the REFACTOR). 4 of 4 exercisable points met, on both the Expected wording and the template's own contract.

1. **Met.** Line-15 thread: `skip`, reason "Rule 1: thread isResolved is true."
2. **Not exercised.** Same thread set as run 1; no thread qualifies.
3. **Not exercised.** Every thread has `isOutdated` false.
4. **Met.** One `reply` (line 5), justified from the code and from a survey of the neighbouring files: "This repository carries no non-functional comments - no other file under src/utils (handleKickOut.ts, buildLoginRedirect.ts, chunkArray.ts, formatStringWithCommas.ts, isValidEmail.ts) carries an inline comment - and the function's own name, clampPercentage, already conveys that 0-100 is the contract by definition of a percentage, not an arbitrary choice needing justification."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry explanatory comments - the function is named clampPercentage, so 0-100 is the contract by definition, not an arbitrary choice that needs justifying in prose. If bounds ever need to be configurable, that's a rename/signature change, not a comment."
6. **Met.** The response is exactly the fenced block, first character to last. The array parses with `jq`, 5 items, 12 fields each, fetch order, every value matching the independent capture, and the conversation comment's `id` is now the string `"5601468962"`.

Bot OSV comment, verbatim reason: "Rule 5: package.json:256 pins vitest ^3.2.6 and yarn.lock resolves both vitest and @vitest/mocker to 3.2.7 at HEAD, matching the flagged vulnerable version exactly. osv-scanner.toml carries three IgnoredVulns entries (GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, GHSA-jrc7-96c5-q579) but none for GHSA-82fw-gwwq-j7x9, so this finding is uncovered. The non-blocking label and devDependency status don't lower this from fix per the task rules." Class `fix`; proposal: bump `vitest` and `@vitest/mocker` from 3.2.7 to 4.1.11 in `package.json` and `yarn.lock`, then regenerate the lockfile with `yarn install`. Both NaN threads were again `fix` under rule 5, each proposal replacing line 6 with a `Number.isNaN` guard, deleting the TODO on line 7, and adding a `clampPercentage(NaN)` test; the class of every item was identical to run 1.

**Run 3 (confirmation, template unchanged from run 2).** 4 of 4 exercisable points met. Identical ids, `reply_to` values, flags, and classes to run 2; the response was again exactly the fenced block, parsing as JSON with `id` strings throughout.

1. **Met.** Line-15 thread: `skip`, "Rule 1: thread isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), justified from the code: "The code is already clear without prose: the function is named clampPercentage, so a fixed 0-100 range is the definition of what it produces, not an arbitrary choice needing justification."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry non-functional comments. The name says it: clampPercentage always clamps to 0-100 because that's what a percentage is. A different range would mean a different function, not a configurable version of this one."
6. **Met.** First character the opening fence, last the closing fence, nothing else. Verbatim from the run-3 response, its first line, the issue-comment item's first two fields, and its last line, with the lines between elided:

````
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

Bot OSV comment, verbatim reason: "Rule 5: scanner finding still applies at HEAD. package.json pins vitest to ^3.2.6, which yarn.lock resolves to 3.2.7, and yarn.lock pins the transitive @vitest/mocker at 3.2.7 too; osv-scanner.toml only ignores GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, and GHSA-jrc7-96c5-q579, so this advisory is not covered." Class `fix`; proposal: bump `vitest` from `^3.2.6` to `^4.1.11` in `package.json` and run `yarn install`, which also lifts `@vitest/mocker`.

**Run 4 (after the spec review trimmed two clauses from the template: "and none lowers a fix to a reply" from the non-reasons sentence, and "no comments, no trailing commas" from the output paragraph).** 4 of 4 exercisable points met. Classes, ids, `reply_to` values, and flags identical to runs 1 to 3.

1. **Met.** Line-15 thread: `skip`, "Rule 1: isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), justified from the code and a survey of the sibling files, verbatim reason: "Rule 8: this asks for an expanded explanatory comment. Checked src/utils — every other file there (buildLoginRedirect.ts, chunkArray.ts, formatStringWithCommas.ts, handleKickOut.ts, isValidEmail.ts) carries zero comments; the function name clampPercentage plus the existing one-line summary above it already state why the range is 0-100 — it's a percentage, so that's the definition, not a configurable choice. Code is clear without added prose, so this is not a fix."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "We don't add explanatory comments in this codebase — every other file in src/utils has none. The name clampPercentage and the summary above it already say why: it's clamping a percentage, and 0 to 100 is the definition of a percentage, not an arbitrary limit. Leaving the comment as is." No prose is proposed. The closing sentence leaves the existing line-5 comment in place rather than proposing its removal; that is outside what this point grades (the prose audit removes it in its own step) and adds nothing, so it is not a regression.
6. **Met.** First character the opening fence, last the closing fence. Verbatim from the run-4 response, its first line, the issue-comment item's first two fields, and its last line, with the lines between elided:

````
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

Bot OSV comment, verbatim reason: "Rule 5: scanner finding not covered by any ignore entry — checked osv-scanner.toml at HEAD, its three IgnoredVulns entries (GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, GHSA-jrc7-96c5-q579) don't include GHSA-82fw-gwwq-j7x9. package.json pins vitest at ^3.2.6 and yarn.lock resolves both vitest and the transitive @vitest/mocker to 3.2.7, so the vulnerable version is still installed. The 'non-blocking' label on the scan is a severity marker, not a reason to skip." Class `fix`; proposal: bump `vitest` from `^3.2.6` to `^4.1.11` in `package.json` and run `yarn install`, noting that `@vitest/mocker` is transitive and follows. Both NaN threads were again `fix` under rule 5 with the `Number.isNaN` guard, TODO removal, and a `clampPercentage(NaN)` test; the issue-comment item carried `false` for `resolved` and `outdated`.

**REFACTOR after run 4.** Run 4's line-5 proposal ended "Leaving the comment as is." That promise is contradicted within the same pr-finalise run: the prose-audit step that follows triage removes every non-functional comment on an added line, and line 5 (`// Guard against callers passing already-bounded values`) is one, so the reviewer would read a reply saying the comment stays and then see it deleted. Runs 2 and 3 made no such promise, so the rule had been silent on the point rather than wrong. Rule 8 gained one clause, after the instruction to point at the naming or structure that makes the code clear: "If the referenced line already carries a non-functional comment, the reply says it is being removed under that convention, never that it stays or will be expanded." Nothing else in the template changed.

**Run 5 (after the second REFACTOR, rule 8 carrying the removal clause).** 4 of 4 exercisable points met. Classes, ids, `reply_to` values, and flags identical to runs 1 to 4.

1. **Met.** Line-15 thread: `skip`, "Rule 1: thread isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), justified from the code, verbatim reason: "Rule 3 then rule 8: this asks for an explanatory comment to be expanded. This repository carries no non-functional comments, so line 5's existing comment ('// Guard against callers passing already-bounded values') is being removed under that convention, not expanded. The function's own name already states the bounds are a percentage's 0-100."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry explanatory code comments, so line 5's comment is being removed rather than expanded. The name clampPercentage already says the bounds are 0-100 — a percentage. If you need different bounds, that's a separate, more generically named clamp function, not a parameter on this one." The reply now says the comment is being removed, no prose is proposed, and the alternative offered is a differently named function.
6. **Met.** First character the opening fence, last the closing fence. Verbatim from the run-5 response, its first line, the issue-comment item's first two fields, and its last line, with the lines between elided:

````
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

Bot OSV comment, verbatim reason: "Rule 5: package.json line 256 pins `\"vitest\": \"^3.2.6\"` and yarn.lock resolves both vitest and @vitest/mocker to 3.2.7, matching the flagged vulnerable version. osv-scanner.toml's IgnoredVulns list only covers GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, and GHSA-jrc7-96c5-q579 — no entry for GHSA-82fw-gwwq-j7x9 — so this finding is live and unignored. Devdependency status and the 'non-blocking' label are not reasons to skip." Class `fix`; verbatim proposal: "Bump vitest from 3.2.7 (package.json line 256, `\"vitest\": \"^3.2.6\"`) to 4.1.11, the stable fixed release for GHSA-82fw-gwwq-j7x9 (5.0.0-rc.2 is also fixed but is a release candidate), and regenerate yarn.lock; @vitest/mocker is pulled in transitively by vitest so it will resolve to a patched version at the same time." Both NaN threads were again `fix` under rule 5 (the `callumthomas` one via rule 3) with the `Number.isNaN` guard, TODO removal, and a `clampPercentage(NaN)` test; the issue-comment item carried `false` for `resolved` and `outdated`.

**Scoping after run 5 (spec re-review).** The removal clause added after run 4 applied to any referenced line carrying a non-functional comment, but the prose-audit step removes comments on lines this PR added only; pre-existing comments on unchanged lines are never touched. A reviewer asking to expand an old comment on an unchanged line would have been promised a removal that never happens. The sentence is now scoped: "If the referenced line was added by this PR and already carries a non-functional comment, the reply says it is being removed under that convention, never that it stays or will be expanded." To let the agent tell added from unchanged, the template gained a `<<BASE>>` placeholder (the PR's base branch name) in the dispatch header and a one-line recipe in rule 8: `git diff -U0 origin/<<BASE>>...HEAD -- <path>` shows whether the line is added. No rule was added for the unchanged-line case: the earlier rule 8 wording (reply citing the convention, point at naming or structure) already covers it, and it is not exercisable on PR 2630 because `clampPercentage.ts` is a new file, so every line of it is added.

**Run 6 (after the scoping, `<<BASE>>` filled with `master` from `gh pr view 2630 --json baseRefName`).** 4 of 4 exercisable points met on the Expected wording; point 6 not met on the template's own output contract. Classes, ids, `reply_to` values, and flags identical to runs 1 to 5.

1. **Met.** Line-15 thread: `skip`, "Rule 1: thread isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), justified from the code and from the added-line check the scoped rule asks for, verbatim reason: "Rule 3: thread started by callumthomas holding a single comment, judged on merit via rules 4-8. Rule 8: this asks for an explanatory comment to be expanded. `git diff -U0 origin/master...HEAD -- src/utils/clampPercentage.ts` shows the whole file, including line 5, was added by this PR, and it already carries a non-functional comment, so the reply says it is being removed under the repo's no-comments convention rather than expanded — the function's own JSDoc ('Clamp a raw percentage into the 0 to 100 range') and the 0/100 literals in the Math.min/Math.max call already make the fixed bounds clear, so the code stays clear without it."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry non-functional comments, so the line 5 comment is coming out rather than being expanded. Why the bounds are fixed: the function's own doc comment already states it clamps into the 0-100 range, and the 0/100 literals in `Math.min(100, Math.max(0, value))` are the bounds — there's nothing configurable to explain. If configurable bounds are wanted, that's a parameter, not a comment." The reply says the comment is being removed and proposes no prose. The unchanged-line branch of the scoped sentence is not exercisable on this PR: the diff recipe shows `clampPercentage.ts` as a new file, so every line of it is added.
6. **Met on the Expected wording, not on the template's contract.** The fenced block is one JSON array, parses, 5 items, 12 fields, `id` a string. But the response opened with narration before the fence, the same failure mode as run 1, which the first REFACTOR countered and runs 2 to 5 respected. Verbatim, the response's first line, then its fence line, the issue-comment item's first two fields, and its last line, with the lines between elided:

````
This confirms the osv-scanner.toml at repo root is the only ignore mechanism, and it has no entry for GHSA-82fw-gwwq-j7x9. All data gathered. Producing final triage output.
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

The output paragraph did not change between runs 5 and 6, so this regression is not caused by the rule 8 scoping; it is the fence-to-fence counter failing to hold on one run out of five since it was added. Reported for a decision before any rule changes.

Bot OSV comment, verbatim reason: "Rule 1's quote-skip doesn't apply — no later top-level comment by callumthomas quotes this. package.json pins `\"vitest\": \"^3.2.6\"` and yarn.lock resolves both `vitest` and `@vitest/mocker` to 3.2.7 at HEAD; osv-scanner.toml's IgnoredVulns list (GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, GHSA-jrc7-96c5-q579) carries no entry for GHSA-82fw-gwwq-j7x9. Rule 5: a scanner finding whose package is still at the vulnerable version and uncovered by an ignore entry is a real defect — the 'non-blocking' label and vitest being a devDependency are not reasons to skip." Class `fix`; verbatim proposal: "Bump `vitest` from ^3.2.6 (resolved 3.2.7) to ^4.1.11 in package.json and regenerate yarn.lock; this also pulls the transitive `@vitest/mocker` resolution off 3.2.7, fixing GHSA-82fw-gwwq-j7x9 for both packages." Both NaN threads were again `fix` under rule 5 (the `callumthomas` one via rule 3) with the `Number.isNaN` guard, TODO removal, and a NaN test; the issue-comment item carried `false` for `resolved` and `outdated`.

**REFACTOR after run 6.** Run 6's response opened, before the fence, with: "This confirms the osv-scanner.toml at repo root is the only ignore mechanism, and it has no entry for GHSA-82fw-gwwq-j7x9. All data gathered. Producing final triage output." The output paragraph had not changed between runs 5 and 6, so the rule 8 scoping did not cause it; the fence-to-fence counter added after run 1 held in runs 2 to 5 and slipped here, making runs 1 and 6 the two occurrences in six runs. Two changes. The output paragraph gained one sentence naming the observed shape: "Progress narration and announcements that the output follows, such as "All data gathered. Producing final triage output.", must not appear before the fence either: the response begins with the fence." And the dispatch header, addressed to the main session rather than the subagent, gained one sentence making the consumer tolerant: the dispatcher parses the first fenced JSON block in the reply and ignores any text outside it, because the fence-to-fence rule reduces narration but does not eliminate it. The second change is the real safeguard for the comment step in SKILL.md; the wording lowers the slip rate but a stochastic slip cannot be worded away.

**Run 7 (after the third REFACTOR, `<<BASE>>` = `master`).** 4 of 4 exercisable points met, on the Expected wording and on the template's own contract. Classes, ids, `reply_to` values, and flags identical to runs 1 to 6.

1. **Met.** Line-15 thread: `skip`, "Rule 1: thread isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), verbatim reason: "Rule 3: thread started by callumthomas with a single comment, judged on merits. Rule 8: this asks for an existing comment to be expanded. `git diff -U0 origin/master...HEAD -- src/utils/clampPercentage.ts` shows line 5 (`// Guard against callers passing already-bounded values`) was added by this PR and already carries a non-functional comment, so per convention it is removed, not expanded. The function name clampPercentage and the literal `Math.min(100, Math.max(0, value))` bounds already make the fixed 0-100 range clear from the code."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry non-functional comments, so the guard comment on line 5 is being removed rather than expanded. The function is named clampPercentage and clamps against the literal 0 and 100 in the next line — the fixed bounds are already clear from the name and the code itself, no comment needed." Says the comment is being removed, proposes no prose. Unchanged-line branch still not exercisable.
6. **Met.** First character the opening fence, last the closing fence. Verbatim from the run-7 response, its first line, the issue-comment item's first two fields, and its last line, with the lines between elided:

````
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

Bot OSV comment, verbatim reason: "Rule 5: yarn.lock resolves vitest@^3.2.6 to version 3.2.7 and @vitest/mocker to 3.2.7 (pulled in as vitest's dependency), matching the flagged vulnerable version. osv-scanner.toml's IgnoredVulns list covers GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, and GHSA-jrc7-96c5-q579 only — GHSA-82fw-gwwq-j7x9 is not ignored, so the finding is a live, uncovered defect at HEAD regardless of vitest being a devDependency or the finding being labelled non-blocking." Class `fix`; verbatim proposal: "Bump vitest (and its @vitest/mocker sub-dependency) from 3.2.7 to 4.1.11 in package.json and yarn.lock to resolve GHSA-82fw-gwwq-j7x9." Both NaN threads were again `fix` under rule 5 (the `callumthomas` one via rule 3) with the `Number.isNaN` guard, TODO removal, and a `clampPercentage(NaN)` test; the issue-comment item carried `false` for `resolved` and `outdated`.

**Run 8 (confirmation, template unchanged from run 7).** 4 of 4 exercisable points met on the Expected wording; point 6 not met on the template's own contract. Classes, ids, `reply_to` values, and flags identical to runs 1 to 7.

1. **Met.** Line-15 thread: `skip`, "Rule 1: isResolved is true."
2. **Not exercised.**
3. **Not exercised.**
4. **Met.** One `reply` (line 5), verbatim reason: "Rule 3: thread started and held solely by callumthomas, judged on merit via rules 4-8. Rule 8: this asks for an explanatory comment to be expanded. git diff -U0 origin/master...HEAD -- src/utils/clampPercentage.ts shows the whole file, including line 5's `// Guard against callers passing already-bounded values`, was added by this PR, so per rule 8 the reply says the comment is being removed under the no-non-functional-comments convention, not expanded."
5. **Met.** Line-5 thread: `reply` under rule 8, verbatim proposal: "This repo doesn't carry non-functional comments, so the guard comment on line 5 is being removed rather than expanded. The 0-100 range is the entire point of a function named clampPercentage; if a caller ever needed different bounds we'd add explicit min/max parameters rather than document a fixed choice in prose." Says the comment is being removed, proposes no prose.
6. **Met on the Expected wording, not on the template's contract.** One JSON array in one fence, parses, 5 items, 12 fields, `id` a string. The response opened with narration before the fence, verbatim, followed by the fence line, the issue-comment item's first two fields, and the last line, with the lines between elided:

````
Confirmed each thread has exactly one comment. All data gathered and verified against HEAD (b2ae6e45). Now producing the final triage output.
```json
    "kind": "issue_comment",
    "id": "5601468962",
```
````

This is the third occurrence of the run-1 failure mode in eight runs (runs 1, 6, 8), one run after the third REFACTOR named the observed shape. Recorded and stopped here, per the decision that the dispatcher tolerance is the safeguard and further wording is a separate call. A second schema slip in this run: the issue-comment item's `location` was `package.json:256`, the code the finding points at, rather than `conversation`; the schema line `"<path>:<line>" | "conversation"` does not say which alternative belongs to which kind. Recorded, no rule changed.

Bot OSV comment, verbatim reason: "No later callumthomas comment quotes this (it's the only issue comment), so rule 1's second sentence doesn't skip it. Rule 5: verified at HEAD that package.json line 256 declares \"vitest\": \"^3.2.6\", yarn.lock resolves both vitest and @vitest/mocker to 3.2.7, and osv-scanner.toml's three IgnoredVulns entries (GHSA-848j-6mx2-7j84, GHSA-qwww-vcr4-c8h2, GHSA-jrc7-96c5-q579) do not cover GHSA-82fw-gwwq-j7x9. Devdependency status is explicitly not a reason to skip. Real, uncovered vulnerability." Class `fix`; verbatim proposal: "Bump the vitest devDependency in package.json from \"^3.2.6\" to \"^4.1.11\" (the stable fixed release; avoid the 5.0.0-rc.2 prerelease), then run yarn install to regenerate yarn.lock so @vitest/mocker resolves to a patched version alongside it." Both NaN threads were again `fix` under rule 5 (the `callumthomas` one via rule 3) with the `Number.isNaN` guard, TODO removal, and a `clampPercentage(NaN)` test; the issue-comment item carried `false` for `resolved` and `outdated`.

**Two clauses kept without a recorded failure behind them.** The dispatch note in the template header (if the subagent's shell does not start in the checkout, prefix the prompt with its absolute path and an instruction to run every command from there) comes from the Task 6 brief, which required dispatching from `<REPO_DIR>` or giving the absolute path with that instruction. Every run recorded here was dispatched that way, with a preamble naming the worktree path and telling the agent to start each command with `cd` into it. The closing line, `resolved` and `outdated` are false for kinds other than thread, completes the output contract for the two non-thread kinds, which have no thread flags to copy from. It was present in every run recorded here; runs 4 to 8 record the issue-comment item carrying `false` for both fields.

**Baseline-to-skill comparison (RED to GREEN).** The baseline met 1 of 4 exercisable points; runs 2 to 5 and 7 met 4 of 4, and runs 1, 6 and 8 met 4 of 4 on the Expected wording with one output-contract slip each, the same one: narration before the fence. Each baseline failure maps to a template clause that closed it: the collapse to Fix/Skip is countered by the paragraph fixing exactly three classes, naming `reply` as a full outcome for rules 4, 6, 7 and 8, and restricting `skip` to rules 1 and 2; the "just expand it" verdict on the line-5 thread is countered by rule 8's ban on proposing prose in any form "however concrete, small, or low-cost the ask looks"; the markdown-and-summary output is countered by the fence-to-fence contract; and the skipped OSV comment is countered by the sentence naming severity labels, "unrelated to this PR's change", devDependency status, and the PR's draft or test purpose as non-reasons, plus rule 5's clause that a scanner finding still at the vulnerable version and not in the ignore file is a real defect. The first REFACTOR iteration (two sentences of verification narration before the fence, and a numeric `id`) was closed by tightening the output paragraph only; the class of every item was stable across all eight runs. The two clauses trimmed after the spec review were never load-bearing: run 4, without them, produced the same classes as runs 1 to 3 and still parsed as JSON. The one judging-rule change, the removal clause added to rule 8 after run 4, changed no class either; it changed what the line-5 reply promises, from keeping the comment to removing it, so the reply no longer contradicts the prose-audit step that follows. The scoping of that clause to added lines after run 5 changed no class either, and run 6 shows the agent running the `<<BASE>>` diff recipe to establish that line 5 is added before promising the removal. Narration before the fence is the one item wording did not close: the fence-to-fence counter added after run 1 held in runs 2 to 5, slipped in run 6, and after the third REFACTOR named the observed shape it held in run 7 and slipped again in run 8, three occurrences in eight runs. The dispatcher tolerance added in the third REFACTOR (parse the first fenced JSON block, ignore text outside it) is the safeguard; whether further wording is worth another run is a separate decision.

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
- Has no notion of a size gate that skips the automated review for a small or dependency-only diff (Scenario C).
- Has no notion of a bounded retry count — repeating a pass until it changes nothing, capped at three passes (Scenario C).
