#!/usr/bin/env python3
import datetime as dt
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ORG = "deliowales"
PR_URL_RE = re.compile(r"https?://github\.com/" + ORG + r"/[A-Za-z0-9_.-]+/pull/\d+")
KEY_RE = re.compile(r"[A-Za-z]+-\d+")


def normalise_key(arg):
    m = KEY_RE.search(arg)
    if not m:
        sys.exit(f"could not find a ticket key in {arg!r}")
    return m.group(0).upper()


def iso(ts_ms):
    return dt.datetime.fromtimestamp(ts_ms / 1000).strftime("%Y-%m-%d %H:%M")


def load_history(path, key):
    sessions = defaultdict(lambda: {"prompts": 0, "key_typed": 0, "project": None, "first": None, "first_ts": None, "last_ts": 0})
    if not path.exists():
        return sessions
    key_lower = key.lower()
    with path.open() as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            sid = rec.get("sessionId")
            if not sid:
                continue
            s = sessions[sid]
            s["prompts"] += 1
            s["project"] = s["project"] or rec.get("project")
            ts = rec.get("timestamp") or 0
            display = rec.get("display") or ""
            if s["first"] is None and display and not display.startswith("/"):
                s["first"] = " ".join(display.split())
                s["first_ts"] = ts
            s["last_ts"] = max(s["last_ts"], ts)
            if key_lower in display.lower():
                s["key_typed"] += 1
    return sessions


def grep_counts(key, files):
    if not files:
        return {}
    out = subprocess.run(["grep", "-c", "-i", "-F", "--", key, *files], capture_output=True, text=True).stdout
    counts = {}
    for line in out.splitlines():
        path, _, n = line.rpartition(":")
        if n.isdigit() and int(n) > 0:
            counts[path] = int(n)
    return counts


def transcript_meta(path, key):
    cwd = None
    branch = None
    first_user = None
    pr_urls = defaultdict(int)
    with path.open(errors="replace") as fh:
        for i, line in enumerate(fh):
            for url in PR_URL_RE.findall(line):
                pr_urls[url] += 1
            if cwd and first_user:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            cwd = cwd or rec.get("cwd")
            branch = branch or rec.get("gitBranch")
            if first_user is None and rec.get("type") == "user":
                content = rec.get("message", {}).get("content")
                text = content if isinstance(content, str) else next((c.get("text") for c in content or [] if isinstance(c, dict) and c.get("text")), "")
                if text and not text.startswith("<"):
                    first_user = " ".join(text.split())[:120]
    return cwd, branch, first_user, dict(pr_urls)


def gh(args):
    try:
        res = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=60)
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return None, str(exc)
    if res.returncode != 0:
        return None, res.stderr.strip()
    return res.stdout, None


def lookup_prs(key, transcript_urls):
    results = {}
    notes = []
    out, err = gh(["search", "prs", "--owner", ORG, key, "--json", "url", "--limit", "30"])
    if err:
        notes.append(f"gh search prs failed: {err}")
    candidates = {item["url"]: "search" for item in json.loads(out or "[]")}
    for url in transcript_urls:
        candidates.setdefault(url, "transcript")
    for url, via in candidates.items():
        out, err = gh(["pr", "view", url, "--json", "url,title,state,headRefName,isDraft,mergedAt,updatedAt"])
        if err:
            notes.append(f"gh pr view {url} failed: {err}")
            continue
        pr = json.loads(out)
        tagged = key.lower() in (pr["title"] + " " + pr["headRefName"]).lower()
        pr["via"] = via
        pr["tagged"] = tagged or via == "search"
        results[url] = pr
    return results, notes


def scan_local_branches(key):
    denv = None
    try:
        cfg = subprocess.run(["dm", "config", "devenv_path"], capture_output=True, text=True, timeout=10).stdout
        denv = cfg.split("=", 1)[1].strip() if "=" in cfg else cfg.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return {}, ["dm not available; skipped local branch scan"]
    found = {}
    notes = []
    services = Path(denv) / "services"
    if not services.is_dir():
        return {}, [f"{services} not found; skipped local branch scan"]
    for repo in sorted(p for p in services.iterdir() if (p / ".git").exists()):
        branches = subprocess.run(["git", "-C", str(repo), "branch", "-a", "--list", f"*{key.lower()}*", "--list", f"*{key}*"], capture_output=True, text=True).stdout
        for raw in branches.splitlines():
            branch = raw.strip().lstrip("* ").replace("remotes/origin/", "")
            if not branch or "HEAD" in branch:
                continue
            out, err = gh(["pr", "list", "--repo", f"{ORG}/{repo.name}", "--head", branch, "--state", "all", "--json", "url,title,state,headRefName,isDraft,mergedAt,updatedAt"])
            if err:
                notes.append(f"gh pr list {repo.name} {branch} failed: {err}")
                continue
            for pr in json.loads(out or "[]"):
                pr["via"] = f"local branch {repo.name}:{branch}"
                pr["tagged"] = True
                found[pr["url"]] = pr
    return found, notes


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: lookup.py <TICKET-KEY> [current-session-id]")
    key = normalise_key(sys.argv[1])
    current = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CLAUDE_SESSION_ID")
    claude_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
    history = load_history(claude_dir / "history.jsonl", key)
    files = sorted(str(p) for p in (claude_dir / "projects").glob("*/*.jsonl"))
    counts = grep_counts(key, files)

    rows = []
    for path, mentions in counts.items():
        p = Path(path)
        sid = p.stem
        if sid == current:
            continue
        cwd, branch, first_user, pr_urls = transcript_meta(p, key)
        h = history.get(sid, {})
        project = cwd or h.get("project") or p.parent.name
        rows.append({
            "session": sid,
            "interactive": bool(h.get("prompts")),
            "branch_has_key": key.lower() in (branch or "").lower(),
            "key_typed": h.get("key_typed", 0),
            "prompts": h.get("prompts", 0),
            "mentions": mentions,
            "last_active": dt.datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
            "project": project,
            "dir_exists": Path(project).is_dir(),
            "branch": branch,
            "first_prompt": h.get("first") or first_user or "",
            "pr_urls": pr_urls,
        })
    for sid, h in history.items():
        if h["key_typed"] and sid != current and not any(r["session"] == sid for r in rows):
            rows.append({
                "session": sid, "interactive": True, "branch_has_key": False, "key_typed": h["key_typed"], "prompts": h["prompts"], "mentions": 0,
                "last_active": iso(h["last_ts"]), "project": h["project"], "dir_exists": Path(h["project"] or "/nonexistent").is_dir(),
                "branch": None, "first_prompt": (h["first"] or "") + "  [transcript missing]", "pr_urls": {},
            })
    for r in rows:
        r["signal"] = "strong" if r["key_typed"] or r["mentions"] >= 100 or (r["branch_has_key"] and r["mentions"] >= 50) else "weak"
    rows.sort(key=lambda r: (r["key_typed"] > 0, r["interactive"], r["branch_has_key"], r["mentions"], r["last_active"]), reverse=True)

    interactive = [r for r in rows if r["interactive"]]
    agents = [r for r in rows if not r["interactive"]]

    print(f"TICKET {key}")
    print(f"current session excluded: {current or '-'}")
    print()
    print(f"INTERACTIVE SESSIONS ({len(interactive)}), best first")
    if not interactive:
        print("  none")
    for i, r in enumerate(interactive[:10], 1):
        print(f"{i}. {r['session']}  [{r['signal']} signal]")
        print(f"   project: {r['project']}  (exists: {'yes' if r['dir_exists'] else 'NO'}; branch at start: {r['branch'] or '-'})")
        print(f"   key typed by user: {r['key_typed']}  prompts: {r['prompts']}  mentions in transcript: {r['mentions']}  last active: {r['last_active']}")
        print(f"   first prompt: {r['first_prompt'][:120]}")
        if r["pr_urls"]:
            urls = sorted(r["pr_urls"].items(), key=lambda kv: -kv[1])
            print("   PR URLs in transcript: " + ", ".join(f"{u} ({n})" for u, n in urls[:8]))
    if len(interactive) > 10:
        print(f"   ... {len(interactive) - 10} more interactive sessions with low signal omitted")
    print()
    print(f"AGENT / TEAMMATE SESSIONS mentioning the key (not resumable as your work): {len(agents)}")
    for r in agents[:5]:
        print(f"   {r['session'][:8]}  {r['project']}  mentions: {r['mentions']}  last active: {r['last_active']}")
    if len(agents) > 5:
        print(f"   ... {len(agents) - 5} more")

    transcript_urls = []
    for r in interactive[:3]:
        if r["signal"] != "strong":
            continue
        for url, n in sorted(r["pr_urls"].items(), key=lambda kv: -kv[1]):
            if n >= 2 and url not in transcript_urls:
                transcript_urls.append(url)
    transcript_urls = transcript_urls[:20]
    primary_urls = set(interactive[0]["pr_urls"]) if interactive else set()
    prs, notes = lookup_prs(key, transcript_urls)
    if not any(pr["tagged"] for pr in prs.values()):
        local, local_notes = scan_local_branches(key)
        prs.update(local)
        notes.extend(local_notes)
    print()
    print(f"PULL REQUESTS ({len(prs)})")
    if not prs:
        print("  none found via gh search, session transcripts, or local branches")
    tagged = [pr for pr in prs.values() if pr["tagged"]]
    untagged = [pr for pr in prs.values() if not pr["tagged"] and pr["url"] in primary_urls]
    skipped = len(prs) - len(tagged) - len(untagged)
    for pr in sorted(tagged, key=lambda p: p["url"]) + sorted(untagged, key=lambda p: p["url"])[:5]:
        state = "merged" if pr.get("mergedAt") else pr["state"].lower()
        flag = "TAGGED" if pr["tagged"] else "untagged (mentioned in primary session only; include only if clearly this ticket)"
        draft = " draft" if pr.get("isDraft") else ""
        print(f"  {pr['url']}  [{state}{draft}]  {flag}  via {pr['via']}")
        print(f"     {pr['title']}  ({pr['headRefName']})")
    if skipped or len(untagged) > 5:
        print(f"  ({skipped + max(0, len(untagged) - 5)} untagged PRs from other sessions omitted)")
    for note in notes:
        print(f"  note: {note}")


if __name__ == "__main__":
    main()
