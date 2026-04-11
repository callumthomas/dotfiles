When spawning subagents for parallelising work, prefer to use 'team members' pattern where possible, team members can spawn their own subagents, allowing them to keep their main context cleaner

When spawning subagents for multi-repo work, use 'team members' pattern (separate Claude instances per repo), not subagents within a single session. Always check branch cleanliness before starting work.

Always use subagents for read heavy tasks such as gathering specific information from logs, reading large files for small subsets of the information they contain, and anything else that might fill up the context with noise that we won't need later.

Do not assume that test failures are pre-existing unless explicitly told so by the user. If you believe a failure is pre-existing, evidence it by checking the CI runs for the main branch of the repo you're working in
