# Comment triage: subagent prompt template

Dispatch as a `general-purpose` subagent from the repo checkout at the PR head. Fill `<<OWNER>>`, `<<REPO>>`, `<<PR>>`, `<<BASE>>` (the PR's base branch name), `<<OUR_LOGIN>>`, `<<HEAD_SHA>>`, and `<<VOICE>>` (the contents of the resolved voice file, or `plain and concise`). If the subagent's shell does not start in the checkout, prefix the prompt with its absolute path and an instruction to run every command from there. The dispatcher parses the first fenced JSON block in the reply and ignores any text outside it, because the fence-to-fence rule reduces narration but does not eliminate it.

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
              id isResolved isOutdated path line originalLine startLine subjectType
              comments(first: 100) { totalCount nodes { databaseId author { login } body createdAt } }
            }
          }
        }
      }
    }'

Conversation comments:

    gh api repos/<<OWNER>>/<<REPO>>/issues/<<PR>>/comments --paginate

Conversation comments and review bodies authored by <<OUR_LOGIN>> are not items; they are context for rule 1's quote test. Review threads are different: a thread started by <<OUR_LOGIN>> is an item, since pr-review posts findings under our login.

Review summaries. A review is an item only when its body contains a request that no thread already carries. Reviews with an empty body, or whose request a thread carries, are not items and do not appear in the output:

    gh api repos/<<OWNER>>/<<REPO>>/pulls/<<PR>>/reviews --paginate

## Judge each item

Read the code at the referenced path and line in the current checkout, with enough surrounding context to decide whether the concern holds against current HEAD. For conversation comments and review bodies, locate the code they refer to. For a dependency scanner finding, that code is the manifest and lockfile entry for the named package at HEAD, plus any scanner ignore file in the repository. On a thread with more than one comment, judge the latest comment that asks for something, using the earlier ones as context; `ask` summarises that comment.

Exactly three classes exist: `fix`, `reply`, `skip`. Every item gets one. `reply` is a full outcome chosen whenever rules 4, 6, 7, or 8 match, not a fallback for items that fit neither of the others. `skip` comes only from rules 1, 1b and 2. No other rule produces it, and a triage with no `reply` on a PR that holds a question or a request for a comment has misapplied the rules.

Apply these rules in order. The first that matches decides.

1. Thread `isResolved` is true: skip. Conversation comment or review body with a later top-level comment by <<OUR_LOGIN>> quoting its text: skip.
1b. The item makes no request, such as a scan summary with no live finding, a review summary of work already done, a deploy preview, a coverage table, a status note, or a link to related work: skip, and the reason names what makes it informational. A comment reporting a finding still present at HEAD is not informational.
2. Thread's last comment is by <<OUR_LOGIN>> and the thread holds more than one comment: skip. We replied and are waiting on them.
3. Thread started by <<OUR_LOGIN>> holding a single comment: an automated-review finding on the author's own PR. Judge on merit with rules 4 to 8.
4. `isOutdated` is true: not a skip. Check current code. If the concern no longer applies, class is reply, and the proposal names the commit that superseded it (find it with `git log -S` or `git blame`). If it still applies, continue. `line` is null on an outdated thread; use `originalLine` with `git log -S` or `git blame` on `path` to find where that code now lives, and set `location` to `<path>:<originalLine>`.
5. The comment identifies a real defect or a worthwhile improvement and you agree after reading the code: fix. The proposal describes the change precisely enough for someone else to make it. A scanner finding whose package is still at the vulnerable version at HEAD and is not covered by an ignore entry is a real defect: the proposal names the package, the installed version, and the fixed version to move to.
6. The comment is incorrect or not applicable here and you can state exactly why with reference to the code: reply, with the justification drafted. "Disagree", "not needed", or "works fine" without a reason is not a justification. If you cannot articulate one, the class is fix.
7. The comment is a question: reply, with the answer drafted from the code. A question whose ask is for an explanatory comment is rule 8's case.
8. The comment asks for an explanatory code comment, whether new, expanded, reworded, or moved: reply, stating that this repository carries no non-functional comments and pointing at the naming or structure that makes the code clear. If the referenced line was added by this PR and already carries a non-functional comment, the reply says it is being removed under that convention, never that it stays or will be expanded. `git diff -U0 origin/<<BASE>>...HEAD -- <path>` shows whether the line is added. If the code is not clear, the class is fix with a rename or extraction. Proposing prose in any form is never an outcome here, however concrete, small, or low-cost the ask looks, and the reviewer's literal wording does not override the convention.

None of these is a reason to skip: a severity or priority label on the comment (`non-blocking`, `low`, `nit`, `Important`); the concern touching code or dependencies this PR did not change; the package being a devDependency; the PR being a draft, a test, or due to be closed. Judge the concern against the code at HEAD and nothing else.

Bot authors (dependabot, coverage tools, static analysers, scanner workflows) and comments by <<OUR_LOGIN>> from earlier automated reviews follow the same rules.

Draft every reply in this voice:

<<VOICE>>

## Output

Your entire response is one JSON array inside a single fenced code block: the response begins with the opening fence and ends with the closing fence, with no narration, heading, summary, or confirmation outside it, and anything you verified about the PR as a whole belongs in the `reason` field of the items it concerns. The array must parse as JSON, and `id` is always a string. A PR with no threads, conversation comments or review bodies yields `[]`, the empty array inside the fence, not a sentence. One object per item, in fetch order, skipped items included:

{
  "kind": "thread" | "issue_comment" | "review_body",
  "id": "<thread node id, or comment or review id>",
  "reply_to": <databaseId of the thread's last comment, or null for other kinds>,
  "location": "<path>:<line>" for kind thread (`<path>:<originalLine>` when outdated), "conversation" for issue_comment and review_body,
  "started_by": "<login>",
  "last_by": "<login>",
  "resolved": true | false,
  "outdated": true | false,
  "ask": "<one sentence>",
  "class": "fix" | "reply" | "skip",
  "rule": "<the rule that decided, as a string, e.g. \"5\" or \"1b\">",
  "reason": "<why, free prose>",
  "proposal": "<for fix: the change; for reply: the full reply text; for skip: empty string>"
}

`resolved` and `outdated` are false for kinds other than thread.
