# Vulnerability remediation with osv-scanner

Whether the finding was introduced by this PR or already present on the base is irrelevant. A failing check blocks merge either way. Fix first; ignore only when fixing is impossible or breaks tests, and never without an expiry.

## Extract findings

From `gh pr checks --json`, take the OSV check's `link`, extract the run id, and read `gh run view <run_id> --log-failed`. osv-scanner prints one row per finding: OSV URL, CVSS, ecosystem, package, version, source path. Record id (the last path segment of the URL), package, version, and source.

## Find the fixed version

```bash
curl -s https://api.osv.dev/v1/vulns/<ID> | jq '[.affected[] | select(.package.name == "<pkg>") | .ranges[].events[] | .fixed // empty]'
```
Target the lowest fixed version greater than the current one. An empty array means no fix is published: go to the ignore route.

## Direct or transitive

| Manager | Reverse dependency query |
|---------|--------------------------|
| npm | `npm explain <pkg>` |
| pnpm | `pnpm why <pkg>` |
| yarn | `yarn why <pkg>` |
| uv | `uv tree --invert --package <pkg>` |
| pip | `pipdeptree -r -p <pkg>` |
| poetry | `poetry show --tree \| grep -B5 <pkg>` |
| go | `go mod why -m <module>` |
| cargo | `cargo tree -i <pkg>` |

Direct if the package appears in the repo's own manifest.

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

Run the repo's test suite. On pass, commit:
```
deps: bump <pkg> to <ver> (<ID>)
```
On failure that is not a quick fix, discard the change with `git checkout -- .` and `git clean -fd` limited to the files you touched, then take the ignore route.

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
- Never omit `ignoreUntil`.
- Never extend an existing entry silently. An expired entry causing the failure is a fresh finding: go back to the fix route. If still unfixable, write a new window and say so in the report.
- No TOML comments. The `reason` field carries the rationale.

Commit:
```
deps: ignore <ID> until <YYYY-MM-DD>
```

## Report row

`id`, `package`, `fixed to <ver>` or `ignored until <date>`, `reason`.
