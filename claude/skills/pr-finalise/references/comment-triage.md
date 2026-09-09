# Comment triage: subagent prompt template

Dispatch as a `general-purpose` subagent from the repo checkout at the PR head. Fill `<<OWNER>>`, `<<REPO>>`, `<<PR>>`, `<<OUR_LOGIN>>`, `<<HEAD_SHA>>`, and `<<VOICE>>` (the contents of the resolved voice file, or `plain and concise`). If the subagent's shell does not start in the checkout, prefix the prompt with its absolute path and an instruction to run every command from there.

---

You are triaging feedback on pull request #<<PR>> in <<OWNER>>/<<REPO>> on behalf of its author, GitHub login <<OUR_LOGIN>>. The checkout in the current directory is at the PR head, <<HEAD_SHA>>. Read-only task: do not post, edit, resolve, commit, push, or modify anything. Use only `gh api` reads, `git diff`, `git show`, `git log`, `git blame`, and file reads.

## Fetch

Review threads, all pages:

    gh api graphql --paginate -F owner=<<OWNER>> -F repo=<<REPO>> -F number=<<PR>> -f query='
    query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id isResolved isOutdated path line
              comments(first: 100) { nodes { databaseId author { login } body createdAt } }
            }
          }
        }
      }
    }'

Conversation comments:

    gh api repos/<<OWNER>>/<<REPO>>/issues/<<PR>>/comments --paginate

Review summaries. A review is an item only when its body contains a request that no thread already carries. Reviews with an empty body, or whose request a thread carries, are not items and do not appear in the output:

    gh api repos/<<OWNER>>/<<REPO>>/pulls/<<PR>>/reviews --paginate

## Judge each item

Read the code at the referenced path and line in the current checkout, with enough surrounding context to decide whether the concern holds against current HEAD. For conversation comments and review bodies, locate the code they refer to. For a dependency scanner finding, that code is the manifest and lockfile entry for the named package at HEAD, plus any scanner ignore file in the repository.

Exactly three classes exist: `fix`, `reply`, `skip`. Every item gets one. `reply` is a full outcome chosen whenever rules 4, 6, 7, or 8 match, not a fallback for items that fit neither of the others. `skip` comes only from rules 1 and 2. No other rule produces it, and a triage with no `reply` on a PR that holds a question or a request for a comment has misapplied the rules.

Apply these rules in order. The first that matches decides.

1. Thread `isResolved` is true: skip. Conversation comment or review body with a later top-level comment by <<OUR_LOGIN>> quoting its text: skip.
2. Thread's last comment is by <<OUR_LOGIN>> and someone else started the thread: skip. We replied and are waiting on them.
3. Thread started by <<OUR_LOGIN>> holding a single comment: an automated-review finding on the author's own PR. Judge on merit with rules 4 to 8.
4. `isOutdated` is true: not a skip. Check current code. If the concern no longer applies, class is reply, and the proposal names the commit that superseded it (find it with `git log -S` or `git blame`). If it still applies, continue.
5. The comment identifies a real defect or a worthwhile improvement and you agree after reading the code: fix. The proposal describes the change precisely enough for someone else to make it. A scanner finding whose package is still at the vulnerable version at HEAD and is not covered by an ignore entry is a real defect: the proposal names the package, the installed version, and the fixed version to move to.
6. The comment is incorrect or not applicable here and you can state exactly why with reference to the code: reply, with the justification drafted. "Disagree", "not needed", or "works fine" without a reason is not a justification. If you cannot articulate one, the class is fix.
7. The comment is a question: reply, with the answer drafted from the code.
8. The comment asks for an explanatory code comment, whether new, expanded, reworded, or moved: reply, stating that this repository carries no non-functional comments and pointing at the naming or structure that makes the code clear. If the code is not clear, the class is fix with a rename or extraction. Proposing prose in any form is never an outcome here, however concrete, small, or low-cost the ask looks, and the reviewer's literal wording does not override the convention.

None of these is a reason to skip, and none lowers a fix to a reply: a severity or priority label on the comment (`non-blocking`, `low`, `nit`, `Important`); the concern touching code or dependencies this PR did not change; the package being a devDependency; the PR being a draft, a test, or due to be closed. Judge the concern against the code at HEAD and nothing else.

Bot authors (dependabot, coverage tools, static analysers, scanner workflows) and comments by <<OUR_LOGIN>> from earlier automated reviews follow the same rules.

Draft every reply in this voice:

<<VOICE>>

## Output

Your entire response is one JSON array inside a single fenced code block. The first character of the response is the opening fence and the last is the closing fence: no heading, no preamble, no per-item commentary, no summary line, no confirmation that nothing was changed. Anything you verified about the PR as a whole, such as no thread being outdated or every finding being checked against HEAD, belongs in the `reason` field of the items it concerns, never in a sentence before the fence. The array must parse as JSON: no comments, no trailing commas, and `id` is always a string. One object per item, in fetch order, skipped items included:

{
  "kind": "thread" | "issue_comment" | "review_body",
  "id": "<thread node id, or comment or review id>",
  "reply_to": <databaseId of the thread's last comment, or null for other kinds>,
  "location": "<path>:<line>" | "conversation",
  "started_by": "<login>",
  "last_by": "<login>",
  "resolved": true | false,
  "outdated": true | false,
  "ask": "<one sentence>",
  "class": "fix" | "reply" | "skip",
  "reason": "<rule number and why>",
  "proposal": "<for fix: the change; for reply: the full reply text; for skip: empty string>"
}

`resolved` and `outdated` are false for kinds other than thread.
