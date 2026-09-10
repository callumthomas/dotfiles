# GitHub and git recipes for pr-finalise

Placeholders: `<o>/<r>` owner and repo, `<n>` PR number, `<us>` our login, `<base>` base branch, `<head>` head branch.

## PR metadata

```bash
gh pr view <n> --json number,url,title,body,state,isDraft,baseRefName,headRefName,headRefOid,isCrossRepository,headRepositoryOwner
gh repo view --json nameWithOwner --jq .nameWithOwner
gh api user --jq .login
```

Scratch files such as reply bodies go under a `mktemp -d` directory, never in the repository, because the same pass runs `git add`.

## OSV workflow behind a `uses:` reference

A workflow file whose `osv-scanner` match is a `uses:` reference to another repository's reusable workflow carries no pinned version or `--config` of its own. `<o>/<r>`, `<path>` and `<ref>` come from the `uses: <o>/<r>/<path>@<ref>` value, not from the PR's repo. Read the referenced workflow directly:

```bash
gh api -H "Accept: application/vnd.github.raw" "repos/<o>/<r>/contents/<path>?ref=<ref>"
```

Take the pinned scanner version and any `--config` argument from its contents.

## Pending review guard

Run before the first reply of every pass. If we hold an unsubmitted review, new comments queue into it invisibly.

```bash
gh api repos/<o>/<r>/pulls/<n>/reviews --paginate --jq '.[] | select(.user.login == "<us>" and .state == "PENDING") | .id'
gh api --method POST repos/<o>/<r>/pulls/<n>/reviews/<review_id>/events -f event=COMMENT
```

Submitting returns 422 `can not submit an empty review` when the pending review holds no queued comments. In that case delete it instead:

```bash
gh api --method DELETE repos/<o>/<r>/pulls/<n>/reviews/<review_id>
```

## Reply to a review thread

`<reply_to>` is the `databaseId` of the thread's last comment.

```bash
gh api repos/<o>/<r>/pulls/<n>/comments/<reply_to>/replies -F body=@"$tmp/reply.md"
```

## Reply to a conversation comment or review body

No reply endpoint exists. Post a new top-level comment whose first line quotes the comment's first heading line, or its first line when it has no heading. For the scanner's sticky comment that quote is `## 🔒 OSV Scan`, without the status suffix: CI rewrites the suffix and the body in place on every run, so a quoted body sentence would stop matching.

```bash
gh pr comment <n> --body-file "$tmp/reply.md"
```

## Resolve a thread

`<thread_id>` is the thread node id from the triage output, not a comment id.

```bash
gh api graphql -f id=<thread_id> -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
```
Expected: `{"data":{"resolveReviewThread":{"thread":{"isResolved":true}}}}`

## Dedup before replying

Thread:
```bash
gh api graphql -f id=<thread_id> -f query='query($id: ID!) { node(id: $id) { ... on PullRequestReviewThread { isResolved comments(last: 1) { totalCount nodes { author { login } body } } } } }'
```
Skip if the last author is `<us>` and `totalCount` is greater than 1. A single-comment thread under `<us>` was opened by pr-review and is unanswered.

Conversation:
```bash
gh api repos/<o>/<r>/issues/<n>/comments --paginate --jq '.[] | select(.user.login == "<us>") | .body'
```
Skip if any body's first line is the heading quote this reply would open with.

## Review marker

Format, one line, on its own paragraph at the end of the body:
```
<!-- pr-finalise: review=<sha | skipped:<reason>> date=<YYYY-MM-DD> -->
```

Read:
```bash
gh pr view <n> --json body --jq .body | grep -E '^<!-- pr-finalise: review=' || echo absent
```

Write (replaces an existing marker, preserves the rest of the body):

Stop if the first command fails. An empty body is legitimate and prints nothing with exit 0; a non-zero exit means gh failed and nothing must be written.

```bash
body=$(gh pr view <n> --json body --jq .body)
tmp=$(mktemp -d)
printf '%s\n' "$body" | grep -v '^<!-- pr-finalise: review=' | cat -s > "$tmp/body.md"
printf '\n<!-- pr-finalise: review=%s date=%s -->\n' '<value>' "$(date +%F)" >> "$tmp/body.md"
gh pr edit <n> --body-file "$tmp/body.md"
```

## Checks

Never `--watch`: it refuses `--json`, has no budget, and outlives the 600-second cap on a foreground shell call. Poll instead, every 30 seconds, inside an explicit budget of 20 minutes per wait. The first call computes `deadline` (now plus 1200 seconds) and `none_until` (now plus 120 seconds) and prints both, along with `checks_tmp`; every re-read of the same wait takes those as inputs instead of recomputing them, so the budget is tracked across calls rather than restarted. Per-call `end` is the earlier of `deadline` and `now + 480`, keeping each call safely under the shell tool's 600-second maximum; a wait cut off by that per-call `end` or by the tool's timeout is re-read with the same `deadline`, `none_until`, and `checks_tmp`, never re-pushed. `none_until` is the 120-second window after a push in which `no checks reported` is retried. `checks_tmp` is printed before the loop starts so a killed call still leaves its data findable. Reaching `deadline` itself prints `BUDGET_SPENT` before breaking, so the budget stop is mechanically detectable; a per-call cutoff short of `deadline` prints nothing extra and is re-read.

```bash
tmp=$(mktemp -d); checks_tmp=$tmp
echo "checks_tmp=$checks_tmp"
deadline=$(( $(date +%s) + 1200 ))
none_until=$(( $(date +%s) + 120 ))
echo "deadline=$deadline none_until=$none_until"
now=$(date +%s)
end=$(( deadline < now + 480 ? deadline : now + 480 ))
while :; do
  gh pr checks <n> --json name,state,bucket,link,workflow > "$tmp/checks.json" 2> "$tmp/checks.err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    jq -e 'any(.[]; .bucket == "pending")' "$tmp/checks.json" > /dev/null
    jrc=$?
    [ "$jrc" -eq 1 ] && break
    if [ "$jrc" -ge 2 ]; then
      echo CHECKS_PARSE_ERROR
      break
    fi
  elif grep -q 'no checks reported' "$tmp/checks.err"; then
    [ "$(date +%s)" -ge "$none_until" ] && break
  else
    break
  fi
  if [ "$(date +%s)" -ge "$end" ]; then
    [ "$(date +%s)" -ge "$deadline" ] && echo BUDGET_SPENT
    break
  fi
  sleep 30
  if [ "$(date +%s)" -ge "$end" ]; then
    [ "$(date +%s)" -ge "$deadline" ] && echo BUDGET_SPENT
    break
  fi
done
echo "rc=$rc"; cat "$tmp/checks.err" "$tmp/checks.json"
```

On a re-read, replace the first lines with `tmp=<checks_tmp>`, `deadline=<deadline>`, `none_until=<none_until>` taken from the first call's output; everything from `now=` down is unchanged.

Without `--json`, exit 0 means every check passed, 8 means pending, and 1 means a failure, no checks, or an API error. With `--json`, gh writes the array and exits 0 whenever checks exist, whatever their state, so classify from the `bucket` field, never from the exit code. `bucket` is one of `pass`, `fail`, `pending`, `skipping`, `cancel`. Treat `fail` and `cancel` as failing. Exit 1 with `no checks reported` on stderr is what gh returns instead of an empty array, including for a few seconds after a push: keep retrying it for 120 seconds after a push (`none_until`); if it persists, print it as its own report line and count zero checks as green, unless preflight recorded an OSV workflow, in which case it is a stop. Any other non-zero exit is an API error: print stderr and stop. `jq -e`'s exit code on the pending test distinguishes the two failure shapes: exit 1 means nothing is pending, and the loop breaks normally; exit 2 or more is a parse error, never read as "all checks complete" — print `CHECKS_PARSE_ERROR` and stop.

Run id from a check's `link` (`.../actions/runs/<run_id>/job/<job_id>`):
```bash
echo '<link>' | sed -E 's#.*/runs/([0-9]+).*#\1#'
```

Failing job log, rerun, and the base branch's latest run of the same workflow:
```bash
gh run view <run_id> --log-failed
gh run rerun <run_id> --failed
gh run list --workflow '<workflow>' --branch <base> --limit 1 --json conclusion,url,createdAt
```

## Size gate

```bash
git diff --numstat origin/<base>...HEAD | awk '$1 != "-" {a += $1; d += $2} END {print a + d}'
git diff --name-only origin/<base>...HEAD
```
The awk sum is the changed-line count; binary files report `-` and are skipped. An empty diff prints 0. Manifest and lockfile names: `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `pyproject.toml`, `poetry.lock`, `uv.lock`, `requirements*.txt`, `Cargo.toml`, `Cargo.lock`, `go.mod`, `go.sum`, `Gemfile`, `Gemfile.lock`, `composer.json`, `composer.lock`.

## Push

```bash
git push origin <head>
```

A rejected push means the remote branch moved. Merge it in, never force, then push again; a second rejection stops the run:

```bash
git fetch origin
git merge origin/<head>
git push origin <head>
```

## Hydration

```bash
git fetch origin
git merge origin/<base>
git diff --name-only --diff-filter=U
git merge --abort
```

`git merge --abort` is for the conflict case only. A clean merge has already committed, and abort then fails with `fatal: There is no merge to abort`.

Lockfiles, and only these, may be auto-resolved: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock`. A conflict in any other file, manifests included, is a stop.

Lockfile-only conflict: take the base branch's lockfile, regenerate it from the merged manifest without upgrading anything, stage, and finish the merge.

```bash
git checkout origin/<base> -- <lockfile>
<regenerate>
git add -- <lockfile>
git commit --no-edit
```

Every other commit in the run stages the same way, `git add -- <paths>` with the paths named; never `git add -A`, `git add .`, or `git commit -a`.

| Manager | Regenerate without upgrading |
|---------|------------------------------|
| npm | `npm install --package-lock-only` |
| pnpm | `pnpm install --lockfile-only` |
| yarn (berry) | `yarn install --mode update-lockfile` |
| yarn (classic) | `yarn install` |
| uv | `uv lock` |
| poetry | `poetry lock` |
| cargo | `cargo update --workspace` |
| go | `go mod tidy` |
| bundler | `bundle lock` |
| composer | `composer update --lock` |

These refresh entries for dependencies already in the lockfile. A dependency the merged manifest newly introduces needs the manager's plain install command instead. Yarn classic installs `node_modules` as a side effect. Before relying on a row, confirm the flag with the manager's `--help` for the version installed.

## Package manager and test command

| Manifest | Lockfile | Manager | Test command |
|----------|----------|---------|---------------|
| `composer.json` | `composer.lock` | composer | `vendor/bin/phpunit` or `vendor/bin/pest`, whichever exists, else `composer test` if the script exists |
| `package.json` | `package-lock.json` | npm | the manifest's `test` script |
| `package.json` | `yarn.lock` | yarn | the manifest's `test` script |
| `package.json` | `pnpm-lock.yaml` | pnpm | the manifest's `test` script |
| `pyproject.toml` | `uv.lock` | uv | pytest |
| `pyproject.toml` | `poetry.lock` | poetry | pytest |
| `pyproject.toml` | `requirements*.txt` | pip | pytest |
| `go.mod` | `go.sum` (if present) | go | `go test ./...` |
| `Cargo.toml` | `Cargo.lock` (if present) | cargo | `cargo test` |

With several manifests present, run the tests of the one whose files the change touched.
