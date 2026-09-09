# GitHub and git recipes for pr-finalise

Placeholders: `<o>/<r>` owner and repo, `<n>` PR number, `<us>` our login, `<base>` base branch, `<head>` head branch.

## PR metadata

```bash
gh pr view <n> --json number,url,title,body,state,isDraft,baseRefName,headRefName,headRefOid,isCrossRepository,headRepositoryOwner
gh repo view --json nameWithOwner --jq .nameWithOwner
gh api user --jq .login
```

## Pending review guard

Run before the first reply of every pass. If we hold an unsubmitted review, new comments queue into it invisibly.

```bash
gh api repos/<o>/<r>/pulls/<n>/reviews --paginate --jq '.[] | select(.user.login == "<us>" and .state == "PENDING") | .id'
gh api --method POST repos/<o>/<r>/pulls/<n>/reviews/<review_id>/events -f event=COMMENT
```

## Reply to a review thread

`<reply_to>` is the `databaseId` of the thread's last comment.

```bash
gh api repos/<o>/<r>/pulls/<n>/comments/<reply_to>/replies -f body="$(cat reply.md)"
```

## Reply to a conversation comment or review body

No reply endpoint exists. Post a new top-level comment whose first line quotes the sentence being answered.

```bash
gh pr comment <n> --body-file reply.md
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
gh api graphql -f id=<thread_id> -f query='query($id: ID!) { node(id: $id) { ... on PullRequestReviewThread { isResolved comments(last: 1) { nodes { author { login } body } } } } }'
```
Skip if the last author is `<us>`.

Conversation:
```bash
gh api repos/<o>/<r>/issues/<n>/comments --paginate --jq '.[] | select(.user.login == "<us>") | .body'
```
Skip if any body's first line is the quote this reply would open with.

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
```bash
gh pr view <n> --json body --jq .body | grep -v '^<!-- pr-finalise: review=' > body.md
printf '\n<!-- pr-finalise: review=%s date=%s -->\n' '<value>' "$(date +%F)" >> body.md
gh pr edit <n> --body-file body.md
```

## Checks

```bash
gh pr checks <n> --watch
gh pr checks <n> --json name,state,bucket,link,workflow
```
`--watch` returns when nothing is pending. Exit 0 means every check passed; any other exit means at least one did not. `bucket` is one of `pass`, `fail`, `pending`, `skipping`, `cancel`. Treat `fail` and `cancel` as failing.

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
git diff --shortstat origin/<base>...HEAD
git diff --name-only origin/<base>...HEAD
```
Changed lines = insertions + deletions. Manifest and lockfile names: `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `pyproject.toml`, `poetry.lock`, `uv.lock`, `requirements*.txt`, `Cargo.toml`, `Cargo.lock`, `go.mod`, `go.sum`, `Gemfile`, `Gemfile.lock`, `composer.json`, `composer.lock`.

## Hydration

```bash
git fetch origin
git merge origin/<base>
git diff --name-only --diff-filter=U
git merge --abort
```

Lockfiles, and only these, may be auto-resolved: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock`. A conflict in any other file, manifests included, is a stop.

Lockfile-only conflict: take the base branch's lockfile, regenerate it from the merged manifest without upgrading anything, stage, and finish the merge.

```bash
git checkout origin/<base> -- <lockfile>
<regenerate>
git add <lockfile>
git commit --no-edit
```

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

Before relying on a row, confirm the flag with the manager's `--help` for the version installed.
