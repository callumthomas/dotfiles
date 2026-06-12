## Agent Dispatch Rules

When I ask to "dispatch a team", "use a team", or "spawn teammates":
- ALWAYS use Agent Teams (TeamCreate + SpawnTeammate), NOT subagents
- Subagents (Task tool) should only be used for quick, isolated lookups
- For any parallel work involving 2+ independent domains, default to Agent Teams
- Use delegate mode — coordinate and assign, do not implement directly


When spawning subagents for parallelising work, prefer to use 'team members' pattern (TeamCreate, SpawnTeammate) where possible, team members can spawn their own subagents, allowing them to keep their main context cleaner

When spawning subagents for multi-repo work, use 'team members' (TeamCreate, SpawnTeammate) pattern (separate Claude instances per repo), not subagents within a single session. Always check branch cleanliness before starting work.

Always use subagents for read heavy tasks such as gathering specific information from logs, reading large files for small subsets of the information they contain, and anything else that might fill up the context with noise that we won't need later.

Do not assume that test failures are pre-existing unless explicitly told so by the user. If you believe a failure is pre-existing, evidence it by checking the CI runs for the main branch of the repo you're working in

When implementing something that uses a third party API or library, always check for accurate API information for the version we're using, either by checking the packages API definitions directly if possible, or by searching for the specific API usage information for the version we're using. We are on rolling releases for system packages etc. so don't assume you know the up to date API specs.

Before suggesting commands or fixes that depend on system state (running services, installed packages, enabled configs, file paths), verify the actual state first. Do not assume services exist, packages are/aren't installed, or that config changes take effect without restarts. Check with systemctl, which, pacman -Q, etc. before recommending.

Never commit directly to main or master. Before committing, always check the current branch. If on main/master (or the repo's default branch), create a new feature branch first before making any commits.


## IMPORTANT
NEVER EVER EVER stub/mock implementations as placeholders unless explicitly asked to do so. Always implement properly, if you believe using a stub as a placeholder may be appropriate, ask first.

## IMPORTANT 
Do NOT write code comments. If you feel like you need to write a code comment then your code isn't self explanatory enough.

## Sibyl Memory

A shared team-memory pool is available via the `sibyl` MCP server. Tools are `mcp__sibyl__memory_save`, `memory_search`, `memory_lookup`, `memory_pin`, `memory_unpin`, `memory_correct`, `memory_invalidate`. Relevant memories are auto-recalled on each prompt via a UserPromptSubmit hook; you don't need to search manually unless doing a targeted lookup.

**Shared pool.** Every caller reads/writes the same memories — phrase facts with explicit entity names ("cal prefers X"), not bare pronouns, so they make sense to other sessions.

**Save inline whenever the conversation produces something a future session should know:**
- Architecture decisions ("we chose X over Y because Z")
- Project-specific conventions and gotchas
- Debugging insights ("error X actually means Y, fix is Z")
- Status changes, deadlines, ownership shifts
- Anything the user explicitly tells you to remember

**Don't save:** routine code changes (git captures those), transient session state, info already in CLAUDE.md / docs.

If a prompt arrives with `⚠ Sibyl unreachable`, skip `memory_save` calls for the turn — they will fail.

## Sibyl Memory Usage
When the user references a graph, service, or codebase already in context, inspect the obvious Sibyl graph FIRST rather than asking for clarification. Save atomic facts (not compound statements) when documenting services, and verify saves succeeded before reporting completion.



always begin every message with the 🐥 emoji, never skip it
