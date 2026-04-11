When spawning subagents for parallelising work, prefer to use 'team members' pattern where possible, team members can spawn their own subagents, allowing them to keep their main context cleaner

When spawning subagents for multi-repo work, use 'team members' pattern (separate Claude instances per repo), not subagents within a single session. Always check branch cleanliness before starting work.

Always use subagents for read heavy tasks such as gathering specific information from logs, reading large files for small subsets of the information they contain, and anything else that might fill up the context with noise that we won't need later.

Do not assume that test failures are pre-existing unless explicitly told so by the user. If you believe a failure is pre-existing, evidence it by checking the CI runs for the main branch of the repo you're working in

When implementing something that uses a third party API or library, always check for accurate API information for the version we're using, either by checking the packages API definitions directly if possible, or by searching for the specific API usage information for the version we're using. We are on rolling releases for system packages etc. so don't assume you know the up to date API specs.

Before suggesting commands or fixes that depend on system state (running services, installed packages, enabled configs, file paths), verify the actual state first. Do not assume services exist, packages are/aren't installed, or that config changes take effect without restarts. Check with systemctl, which, pacman -Q, etc. before recommending.

Never commit directly to main or master. Before committing, always check the current branch. If on main/master (or the repo's default branch), create a new feature branch first before making any commits.
