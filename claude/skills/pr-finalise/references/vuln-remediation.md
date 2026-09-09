# Vulnerability remediation with osv-scanner

Whether the finding was introduced by this PR or already present on the base is irrelevant, and so is whether the check is failing: a finding live at HEAD and uncovered by an ignore entry is worked. This file is reached from step 3, for a failing OSV check or a live finding in the scanner's PR comment, and from step 2, for a `fix` item whose ask is a dependency version or a vulnerability. Both take the same routes in the same order: fix route, then the micro-framework section where the chain passes through it, then override, then revert and ignore. Ignore only when fixing is impossible or breaks tests, and never without an expiry.

## Extract findings

The Delio scan is a reusable workflow that reports every finding, blocking or not, in a sticky PR comment headed `## 🔒 OSV Scan`, as a markdown table `Vulnerability | CVSS | Blocking | Package | Version | Fixed version | Ecosystem | Source`, with each id inside a markdown link `[ID](https://osv.dev/ID)`. That table is the primary source: read it with `gh api repos/<o>/<r>/issues/<n>/comments`, take the id from the link text, and take package, version, fixed version, ecosystem, and source from their columns. The job log, `gh run view <run_id> --log-failed` with the run id from the OSV check's `link`, carries the same facts as `::error` annotations for blocking findings only. A finding whose `Fixed version` column reads `none`, or a scan that prints raw osv-scanner rows without one, takes the api.osv.dev lookup below.

## Find the fixed version

Skip when the comment's table already gives it. Otherwise:

```bash
advisory=$(curl -sf https://api.osv.dev/v1/vulns/<ID>)
printf '%s' "$advisory" | jq '[.affected[] | select(.package.ecosystem == "<ecosystem>" and .package.name == "<pkg>") | .ranges[]?.events[]? | .fixed // empty]'
```
Target the lowest fixed version greater than the current one. An empty array means no fix is published: go to the ignore route. A non-zero exit from the curl line, or from jq, is an error, not an empty result: open the advisory page at `https://osv.dev/vulnerability/<ID>` and read the fixed versions from there before deciding.

Prefer the lowest fixed version inside the range the manifest already allows. When the only fixed version crosses a major boundary: for a direct dependency, attempt the bump and let the tests decide; for a transitive dependency, do not override across a major version, take the ignore route and name the required major and what blocks it in the reason.

## Direct or transitive

| Manager | Reverse dependency query |
|---------|--------------------------|
| npm | `npm explain <pkg>` |
| pnpm | `pnpm why <pkg>` |
| yarn | `yarn why <pkg>` |
| uv | `uv tree --frozen --invert --package <pkg>` |
| pip | `pipdeptree -r -p <pkg>` |
| poetry | `poetry show --tree \| grep -B5 <pkg>` |
| go | `go mod why -m <module>` |
| cargo | `cargo tree --frozen -i <pkg>` |
| composer | `composer why <pkg>` |
| bundler | `gem dependency -R <gem>` |

Direct if the package appears in the repo's own manifest.

## Dependencies reached through the Delio micro-framework

If the reverse-dependency chain passes through any `@deliowales/micro-*` or `@deliowales/lib-*` package, the vulnerable version is pinned by the framework, which is released in lockstep from `deliowales/micro-framework`. Check for a framework release that already carries the fix before touching the transitive dependency directly.

```bash
gh release list -R deliowales/micro-framework --limit 10
gh api -H "Accept: application/vnd.github.raw" "repos/deliowales/micro-framework/contents/package-lock.json?ref=<tag>" | jq -r '.packages | to_entries[] | select(.key | test("node_modules/<pkg>$")) | "\(.key) \(.value.version)"'
```

Walk the releases newer than the version the repo installs from oldest to newest and stop at the first where every resolved entry for the package is at or above the fixed version: the lowest release that carries the fix, not the newest. Bump every `@deliowales/micro-*` and `@deliowales/lib-*` entry in the manifest to `^<release>` together, run the manager's install, run the tests, stage the manifest and lockfile with `git add -- <manifest> <lockfile>`, and commit:
```
deps: bump micro-framework to <release> (<ID>)
```

If no release carries the fix, follow the transitive rules below, and list the framework package and the missing bump under "Left for you" in the report.

## Fix route

Direct dependency: edit the manifest to the target version, then regenerate the lockfile with the manager's normal install command.

Transitive dependency:

| Manager | Override |
|---------|----------|
| npm | `"overrides": {"<pkg>": "<ver>"}` in package.json, then `npm install` |
| yarn | `"resolutions": {"<pkg>": "<ver>"}` in package.json, then `yarn install` |
| pnpm | `"pnpm": {"overrides": {"<pkg>": "<ver>"}}` in package.json, then `pnpm install` |
| uv | `[tool.uv] override-dependencies = ["<pkg>==<ver>"]` in pyproject.toml, then `uv lock` |
| pip | `<pkg>==<ver>` in the constraints file the install references, or a direct pin in requirements |
| poetry | add `<pkg> = ">=<ver>"` as a direct dependency, then `poetry lock` |
| go | `go get <module>@<ver>` then `go mod tidy` |
| cargo | `cargo update -p <pkg> --precise <ver>`; if the target is outside the semver range the manifest allows, stop and report |
| composer | pin `<pkg>` at `>=<ver>` in `require` then `composer update <pkg>` |
| bundler | add `gem '<gem>', '>= <ver>'` to the Gemfile then `bundle lock --update <gem>` |

Run the repo's test suite. On pass, stage with `git add -- <manifest> <lockfile>` and commit:
```
deps: bump <pkg> to <ver> (<ID>)
```
On failure that is not a quick fix, restore only the files you edited, naming them explicitly, then take the ignore route:

```bash
git restore --source=HEAD --worktree -- <manifest> <lockfile>
```

## Ignore route

Config file: the path preflight recorded. That is the workflow's explicit `--config <path>` if present, else `osv-scanner.toml` in the directory of the scanned lockfile named in the finding's `source` column, created if it does not exist. Format, confirmed against https://google.github.io/osv-scanner/configuration/ on 2026-09-09:

```toml
[[IgnoredVulns]]
id = "<ID>"
ignoreUntil = <YYYY-MM-DD>
reason = "<why the fix route failed, and what would unblock it>"
```

`ignoreUntil` is an unquoted TOML date. Compute it with `date -d "+<days> days" +%F`, where days is 7 unless the run was invoked with `--ignore-days`. Before writing, re-read the configuration page for the osv-scanner version the workflow pins and adjust if the field names differ.

Rules:
- Never omit `ignoreUntil` on an entry this run writes. The 7-day rule applies to those entries only.
- Existing entries are never touched, with one exception: the single expired entry whose expiry caused this failure. An expired entry is a fresh finding: go back to the fix route. If still unfixable, edit that entry in place with a new `ignoreUntil` and updated `reason`, never add a second entry for the same id, and say so in the report.
- An existing entry with no `ignoreUntil` is left exactly as it is: a human chose that, and it is not this run's to date.
- No TOML comments. The `reason` field carries the rationale.

Stage with `git add -- <config path>` and commit:
```
deps: ignore <ID> until <YYYY-MM-DD>
```

## Report row

`id`, `package`, one of `fixed to <ver>`, `already fixed`, or `ignored until <date>`, `reason`. `already fixed` is the row for a package already at or above the fixed version at HEAD, verified and not worked.
