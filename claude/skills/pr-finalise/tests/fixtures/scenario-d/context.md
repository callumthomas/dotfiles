# Scenario D context (all values are given; this is a desk exercise, run nothing)

Today is 2026-09-09. The run was invoked without `--ignore-days`. PR head branch `feat/holdings-export`, base `master`, repo deliowales/delio-frontend, package manager yarn (classic, `yarn.lock`), tests `yarn test`.

## Dependency chains at HEAD (`yarn why` output, abbreviated)

    yarn why vitest
    => "vitest@3.2.7" is a direct devDependency ("vitest": "^3.2.6" in package.json)

    yarn why minimatch
    => "minimatch@3.0.4"
       - Hoisted from "@deliowales/lib-http-client#glob#minimatch"
       - Hoisted from "@deliowales/lib-settings#glob#minimatch"

    yarn why tar
    => "tar@6.1.11"
       - Hoisted from "node-gyp#tar" (devDependency chain via node-sass)

    yarn why undici
    => "undici@6.21.2" is a direct dependency ("undici": "^6.21.2" in package.json)
       (the scanner's comment is from the previous CI run; this PR already bumped undici from 6.19.2 to 6.21.2 in an earlier commit)

## Micro-framework

package.json pins sixteen `@deliowales/lib-*` and `@deliowales/micro-*` packages at `^35.0.0`; yarn.lock resolves all of them to 35.3.0. `gh release list --repo deliowales/micro-framework` shows v35.4.0 (2026-09-04), v35.3.0, v35.2.1, v35.2.0. The framework's root `package-lock.json` resolves `node_modules/minimatch` to 3.0.4 at v35.3.0 and to 3.1.2 at v35.4.0. Later framework releases do not exist.

## Test outcomes if you make these changes (given)

- Bump vitest to 4.1.11 and regenerate yarn.lock: 3 test suites fail with `vi.mock` hoisting errors in 40 files; migrating them is a multi-hour job.
- Bump every micro-framework package to ^35.4.0 and regenerate yarn.lock: all tests pass; minimatch resolves to 3.1.2.
- No fixed version exists for tar 6.x.

## OSV config

`osv-scanner.toml` sits at the repo root beside `yarn.lock` (the reusable workflow passes no `--config`). Its content is in `osv-scanner.toml` in this directory.
