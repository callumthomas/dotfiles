---
name: resume-ticket
description: Pick a Delio Jira ticket (HCP-XXX) back up. Finds the Claude Code session to resume and the PRs for the work, and prints the three-line resume block.
argument-hint: HCP-XXX
disable-model-invocation: true
allowed-tools: ToolSearch, AskUserQuestion, Bash(/home/cal/.claude/skills/resume-ticket/scripts/lookup.py:*), Bash(gh pr view:*), Bash(gh search prs:*), mcp__claude_ai_Atlassian__getJiraIssue
---

# resume-ticket

Print the block that gets a ticket's previous Claude session and its PRs back in front of the user:

```
HCP-648 - Portfolio exports for Capital Calls, Requests, Underlyings and Cash Pool
Claude: cd /home/cal/dev/denv/services/portfolio && cc -r edb0e32a-d88b-4ad7-a663-45e94be5f2c8
PRs: https://github.com/deliowales/portfolio/pull/1468 · https://github.com/deliowales/delio-frontend/pull/2531
```

**Core principle: the bundled script gathers, you judge.** Every fact in the block comes from the script output or `gh`; nothing is recalled from memory or inferred from a transcript you read yourself.

Ticket argument: `$ARGUMENTS`. Accept a key in any case or a Jira URL. If empty, ask for it and stop.

## Step 1: Run the lookup

```bash
${CLAUDE_SKILL_DIR}/scripts/lookup.py <KEY> ${CLAUDE_SESSION_ID}
```

It scans `~/.claude/history.jsonl` and every transcript under `~/.claude/projects/` in one pass, then verifies PR candidates with `gh`. It prints, best first:

- **Interactive sessions**: sessions the user drove, with a `strong` or `weak` signal, whether the user typed the key, prompt and mention counts, the project directory and whether it still exists, the first prompt, and PR URLs found in the transcript.
- **Agent / teammate sessions**: excluded from resumption. They are listed only so the count is visible.
- **Pull requests**: `TAGGED` when the key appears in the title or branch or `gh search` matched it; `untagged` when the URL merely appeared in the primary session. State is `open`, `merged`, `closed`, or `draft`.

Never grep or read transcript files yourself. They are hundreds of megabytes of noise and the script already extracted what matters. If the script errors, report the error and stop; do not hand-roll a search.

## Step 2: Fetch the ticket summary

Load `mcp__claude_ai_Atlassian__getJiraIssue` via `ToolSearch` and fetch `summary` and `status` for the key (cloudId `helmmarkets.atlassian.net`). If the connector is unavailable, fall back to the PR titles and the first prompt.

## Step 3: Choose the session

1. The primary is the first `strong` interactive session that is about this ticket. A session counts as about the ticket when its first prompt names it, or when it ran on a branch carrying the key, even if the prompt never says the key. Skip a strong session whose first prompt names a different ticket or is a board overview; those mention the key incidentally.
2. When a denv-level lead session (project `<denv>`, key typed, PR URLs from more than one repository in its transcript) coordinated per-repo sessions, the lead is primary and the per-repo sessions become `Also` lines.
3. Other `strong` interactive sessions about this ticket become `Also` lines. `weak` sessions and agent sessions never appear.
4. If no strong session survives, the Claude line reads `Claude: no session found`, followed by at most one `Maybe:` line for the best weak candidate, and only if its first prompt plausibly concerns this ticket. A board overview, a Jira listing, or a prompt about another ticket does not qualify.
5. If the primary's project directory no longer exists (a removed worktree), keep the session ID, use the repo root as the `cd` target, and add a note that the worktree is gone.

## Step 4: Choose the PRs

- Include every `TAGGED` PR. Order: the PR in the primary session's own repository first, then the rest alphabetically by repository. Closed and merged PRs stay in; the user asked for them annotated, not hidden.
- Include an `untagged` PR only when its title or branch describes the same change as the tagged PRs. A PR for another key, or unrelated infrastructure work, that happened to be discussed in the same session is excluded.
- Do not trust a PR list quoted inside a transcript as complete. The script's `gh search` plus verified transcript URLs is the source of truth.
- Annotate state after the URL only when not open: `(merged)`, `(closed)`, `(draft)`. Join with ` · `. If nothing qualifies: `PRs: none found`.

## Step 5: Print the block

Line 1: `KEY - brief one-line description` in plain words, written from the Jira summary and PR titles. Strip `[TAG] - Area -` prefixes; say what the work does.

Line 2: `Claude: cd <project directory> && cc -r <session id>`.

Line 3: `PRs: ...`.

Optional lines, only when they carry information:

- `Also: cd <project> && cc -r <id>  (<last active date>, "<first 60 characters of the first prompt>")`, one per extra session.
- One short note when no PR is still open (the work may be finished), when the primary's directory is missing, or when the ticket status contradicts the PR states.

Print nothing else. No narration about how it was found, no headings, no code fences.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Grepping `~/.claude/projects` by hand | Run the script. It is faster and keeps transcripts out of context. |
| Picking a session with the most mentions | Teammate sessions mention the key hundreds of times. Only interactive sessions count. |
| Trusting a transcript's "the eight PRs" list | Lists inside transcripts are snapshots. Use the script's verified set. |
| Dropping closed PRs | Closed and merged PRs are part of the record; annotate them. |
| Adding PRs from other tickets seen in the same session | Only PRs tagged with this key, or clearly about it, belong on the line. |
| Copying the Jira summary verbatim | Line 1 is a brief plain description of the work, not the ticket's bracketed summary. |
| Explaining the search | The output is the block. Nothing else. |
