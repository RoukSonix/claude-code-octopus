#!/usr/bin/env python3
"""
AI Agents Marketplace - Universal Installer

Single cross-platform installer for macOS, Linux, and Windows.
Requires only Python 3.7+ with no external dependencies.

Usage:
    # Remote install (macOS / Linux)
    python3 <(curl -fsSL https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py) --all

    # Remote install (Windows PowerShell)
    Invoke-WebRequest https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py -OutFile install.py; python install.py --all

    # Local install
    python3 marketplace/install.py --all --cli claude --target-dir ~/my-project

    # Browse / search
    python3 marketplace/install.py --list
    python3 marketplace/install.py --search security
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple

__version__ = "1.0.0"

REPO_URL = "https://github.com/rouksonix/claude-code-octopus.git"
REPO_ARCHIVE_URL = "https://github.com/rouksonix/claude-code-octopus/archive/refs/heads/main.tar.gz"
REPO_ZIP_URL = "https://github.com/rouksonix/claude-code-octopus/archive/refs/heads/main.zip"
MARKETPLACE_JSON_URL = "https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace.json"


# ── Terminal Colors (cross-platform) ────────────────────────────────────────

def _init_colors():
    """Enable colors on all platforms including Windows 10+."""
    if os.name == "nt":
        # Enable ANSI escape codes on Windows 10+
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
            handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
            mode = ctypes.c_ulong()
            kernel32.GetConsoleMode(handle, ctypes.byref(mode))
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
        except Exception:
            return False
    return sys.stdout.isatty()


_COLORS_ENABLED = _init_colors()


class C:
    """Terminal color codes."""
    if _COLORS_ENABLED:
        RED = "\033[0;31m"
        GREEN = "\033[0;32m"
        YELLOW = "\033[1;33m"
        BLUE = "\033[0;34m"
        CYAN = "\033[0;36m"
        MAGENTA = "\033[0;35m"
        BOLD = "\033[1m"
        DIM = "\033[2m"
        NC = "\033[0m"
    else:
        RED = GREEN = YELLOW = BLUE = CYAN = MAGENTA = BOLD = DIM = NC = ""


def ok(msg: str):
    print(f"  {C.GREEN}+{C.NC} {msg}")


def warn(msg: str):
    print(f"  {C.YELLOW}!{C.NC} {msg}")


def err(msg: str):
    print(f"  {C.RED}x{C.NC} {msg}", file=sys.stderr)


def info(msg: str):
    print(f"  {C.BLUE}>{C.NC} {msg}")


def dim(msg: str):
    print(f"  {C.DIM}{msg}{C.NC}")


def header():
    os_name = platform.system()
    print()
    print(f"  {C.BOLD}{C.CYAN}AI Agents Marketplace{C.NC} {C.DIM}v{__version__}{C.NC}")
    print(f"  {C.DIM}Platform: {os_name} | Python {platform.python_version()}{C.NC}")
    print(f"  {C.DIM}{'─' * 50}{C.NC}")
    print()


def section(title: str, count: Optional[int] = None):
    suffix = f" ({count})" if count is not None else ""
    print(f"  {C.BOLD}{C.CYAN}{title}{suffix}{C.NC}")
    print(f"  {C.DIM}{'─' * 50}{C.NC}")


# ── Network helpers ─────────────────────────────────────────────────────────

def _download(url: str, dest: Path):
    """Download a URL to a local file. Uses urllib (stdlib)."""
    import urllib.request
    import urllib.error

    try:
        urllib.request.urlretrieve(url, str(dest))
    except urllib.error.URLError as e:
        err(f"Download failed: {url}")
        err(f"  {e}")
        sys.exit(1)


# ── Marketplace Data ────────────────────────────────────────────────────────

def find_marketplace_json() -> Path:
    """Find marketplace.json locally or download it."""
    # Check local paths relative to script, parent, and cwd
    script_dir = Path(__file__).resolve().parent if "__file__" in dir() else Path.cwd()
    candidates = [
        script_dir / "marketplace.json",
        script_dir.parent / "marketplace.json",
        Path.cwd() / "marketplace.json",
    ]
    for p in candidates:
        if p.is_file():
            return p

    info("Downloading marketplace registry...")
    tmp = Path(tempfile.mkdtemp()) / "marketplace.json"
    _download(MARKETPLACE_JSON_URL, tmp)
    return tmp


def load_marketplace(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ── Repo Source ─────────────────────────────────────────────────────────────

def find_repo_root() -> Path:
    """Find repo root locally or download it."""
    script_dir = Path(__file__).resolve().parent if "__file__" in dir() else Path.cwd()
    candidates = [script_dir.parent, script_dir, Path.cwd()]
    for p in candidates:
        if (p / ".claude").is_dir() and (p / "marketplace.json").is_file():
            return p

    info("Downloading marketplace repository...")
    return _clone_or_download()


def _clone_or_download() -> Path:
    """Clone via git, or download archive as fallback."""
    tmp_base = Path(tempfile.mkdtemp())

    # Try git clone
    try:
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(tmp_base / "repo")],
            check=True, capture_output=True, text=True,
        )
        ok("Cloned repository")
        return tmp_base / "repo"
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    # Fallback: download archive
    if platform.system() == "Windows":
        return _download_zip(tmp_base)
    else:
        return _download_tarball(tmp_base)


def _download_tarball(tmp_base: Path) -> Path:
    import tarfile
    archive = tmp_base / "repo.tar.gz"
    _download(REPO_ARCHIVE_URL, archive)
    with tarfile.open(archive, "r:gz") as tar:
        tar.extractall(tmp_base, filter="data")
    return _find_extracted_dir(tmp_base)


def _download_zip(tmp_base: Path) -> Path:
    import zipfile
    archive = tmp_base / "repo.zip"
    _download(REPO_ZIP_URL, archive)
    with zipfile.ZipFile(archive, "r") as zf:
        zf.extractall(tmp_base)
    return _find_extracted_dir(tmp_base)


def _find_extracted_dir(tmp_base: Path) -> Path:
    for child in tmp_base.iterdir():
        if child.is_dir() and child.name.startswith("claude-code-octopus"):
            ok("Downloaded repository archive")
            return child
    err("Failed to find repo in downloaded archive")
    sys.exit(1)


# ── List / Search / Info ────────────────────────────────────────────────────

def _cli_badge(item: dict) -> str:
    """Return a compact CLI support badge."""
    parts = []
    if item.get("compatibility", {}).get("claude-code", {}).get("supported"):
        parts.append(f"{C.GREEN}Claude{C.NC}")
    if item.get("compatibility", {}).get("codex", {}).get("supported"):
        parts.append(f"{C.BLUE}Codex{C.NC}")
    return " ".join(parts) if parts else f"{C.DIM}none{C.NC}"


def cmd_list(data: dict):
    header()
    for item_type, label in [("agent", "Agents"), ("command", "Commands"), ("skill", "Skills")]:
        items = [i for i in data["items"] if i["type"] == item_type]
        section(label, len(items))
        for item in items:
            badge = _cli_badge(item)
            print(f"    {C.BOLD}{item['id']}{C.NC}")
            print(f"    {C.DIM}{item['description']}{C.NC}")
            print(f"    CLI: {badge}")
            if item.get("mcp_required"):
                mcps = ", ".join(item["mcp_required"])
                print(f"    MCP: {C.MAGENTA}{mcps}{C.NC}")
            print()
    _print_stats(data)


def cmd_search(data: dict, query: str):
    header()
    print(f"  Search: {C.BOLD}{query}{C.NC}\n")

    q = query.lower()
    results = []
    for item in data["items"]:
        score = 0
        if q in item.get("name", "").lower():
            score += 3
        if q in item.get("displayName", "").lower():
            score += 2
        if any(q == t.lower() for t in item.get("tags", [])):
            score += 2
        if any(q in t.lower() for t in item.get("tags", [])):
            score += 1
        if q in item.get("description", "").lower():
            score += 1
        if score > 0:
            results.append((score, item))

    results.sort(key=lambda x: -x[0])

    if not results:
        warn(f"No items found matching '{query}'")
        return

    print(f"  {C.DIM}Found {len(results)} item(s){C.NC}\n")
    for _, item in results:
        badge = _cli_badge(item)
        tags = ", ".join(item.get("tags", []))
        print(f"  {C.BOLD}[{item['type']}]{C.NC} {item['id']}")
        print(f"    {item['description']}")
        print(f"    Tags: {C.DIM}{tags}{C.NC}  CLI: {badge}")
        if item.get("mcp_required"):
            print(f"    MCP: {C.MAGENTA}{', '.join(item['mcp_required'])}{C.NC}")
        print()


def cmd_categories(data: dict):
    header()
    for sect_name, cats in data.get("categories", {}).items():
        section(sect_name.title())
        for key, val in cats.items():
            icon = val.get("icon", "")
            label = val.get("label", key)
            desc = val.get("description", "")
            print(f"    {icon} {C.BOLD}{label}{C.NC} ({key})")
            print(f"      {C.DIM}{desc}{C.NC}")
        print()


def cmd_info(data: dict, item_id: str):
    """Show detailed info about a specific item."""
    header()
    item = next((i for i in data["items"] if i["id"] == item_id), None)
    if not item:
        err(f"Item not found: {item_id}")
        return

    display = item.get("displayName", item["name"])
    print(f"  {C.BOLD}{display}{C.NC}  {C.DIM}({item['id']}){C.NC}")
    print(f"  Type: {item['type']}")
    print(f"  Category: {item.get('category', 'N/A')}")
    print(f"  {item['description']}")
    print()

    tags = ", ".join(item.get("tags", []))
    print(f"  Tags: {tags}")

    if item.get("mcp_required"):
        print(f"  MCP required: {C.MAGENTA}{', '.join(item['mcp_required'])}{C.NC}")

    if item.get("tools"):
        print(f"  Tools: {', '.join(item['tools'])}")

    print()
    print(f"  {C.BOLD}Compatibility:{C.NC}")
    for cli_key, cli_label in [("claude-code", "Claude Code"), ("codex", "Codex CLI")]:
        compat = item.get("compatibility", {}).get(cli_key, {})
        if compat.get("supported"):
            path = compat.get("path", "")
            inv = compat.get("invocation", "")
            status = f"{C.GREEN}supported{C.NC}"
            details = []
            if inv:
                details.append(f"invoke: {inv}")
            if path:
                details.append(f"path: {path}")
            detail_str = f" ({', '.join(details)})" if details else ""
            print(f"    {cli_label}: {status}{detail_str}")
        else:
            note = compat.get("note", "")
            note_str = f" — {note}" if note else ""
            print(f"    {cli_label}: {C.DIM}not supported{note_str}{C.NC}")

    print()
    print(f"  {C.BOLD}Install:{C.NC}")
    print(f"    python3 marketplace/install.py --item {item['id']}")
    print()


def _print_stats(data: dict):
    stats = data.get("stats", {})
    print(f"  {C.BOLD}Total: {stats.get('total', '?')} items{C.NC}")
    print(f"    Claude Code: {C.GREEN}{stats.get('claude_code_supported', '?')}{C.NC} supported")
    print(f"    Codex CLI:   {C.BLUE}{stats.get('codex_supported', '?')}{C.NC} supported")
    print()


# ── Install ─────────────────────────────────────────────────────────────────

def _copy_item(repo_root: Path, src: str, dst: Path, name: str, dry_run: bool) -> bool:
    src_path = repo_root / src

    if dry_run:
        dim(f"[DRY RUN] Would install: {name} -> {dst}")
        return True

    dst.parent.mkdir(parents=True, exist_ok=True)

    if src_path.is_dir():
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src_path, dst)
        ok(f"{name} -> {dst}")
        return True
    elif src_path.is_file():
        shutil.copy2(src_path, dst)
        ok(f"{name} -> {dst}")
        return True
    else:
        err(f"Source not found: {src_path}")
        return False


def _install_item(
    data: dict, repo_root: Path, item_id: str,
    target_cli: str, target_dir: Path, dry_run: bool,
) -> Tuple[bool, List[str]]:
    """Install a single item. Returns (installed, mcp_servers_needed)."""
    item = next((i for i in data["items"] if i["id"] == item_id), None)
    if not item:
        err(f"Item not found: {item_id}")
        return False, []

    display = item.get("displayName", item["name"])
    installed = False
    mcps = item.get("mcp_required", [])

    for cli_key, cli_short in [("claude-code", "claude"), ("codex", "codex")]:
        if target_cli not in ("both", cli_short):
            continue

        compat = item.get("compatibility", {}).get(cli_key, {})
        if not compat.get("supported"):
            if target_cli != "both":
                warn(f"{display} is not supported for {cli_key}")
            continue

        path = compat.get("path")
        if not path:
            continue

        dst = target_dir / path
        if _copy_item(repo_root, path, dst, f"{display} ({cli_key})", dry_run):
            installed = True

    return installed, mcps if installed else []


def _install_by_type(
    data: dict, repo_root: Path, item_type: str,
    target_cli: str, target_dir: Path, dry_run: bool,
) -> Tuple[int, List[str]]:
    items = [i for i in data["items"] if i["type"] == item_type]
    count = 0
    all_mcps: List[str] = []
    for item in items:
        installed, mcps = _install_item(data, repo_root, item["id"], target_cli, target_dir, dry_run)
        if installed:
            count += 1
            all_mcps.extend(mcps)
    return count, all_mcps


def _install_by_category(
    data: dict, repo_root: Path, category: str,
    target_cli: str, target_dir: Path, dry_run: bool,
) -> Tuple[int, List[str]]:
    items = [i for i in data["items"] if i.get("category") == category]
    if not items:
        err(f"No items found in category: {category}")
        return 0, []

    count = 0
    all_mcps: List[str] = []
    for item in items:
        installed, mcps = _install_item(data, repo_root, item["id"], target_cli, target_dir, dry_run)
        if installed:
            count += 1
            all_mcps.extend(mcps)
    return count, all_mcps


def _print_summary(counts: Dict[str, int], mcps: List[str], dry_run: bool):
    """Print installation summary with MCP server notices."""
    print()
    total = sum(counts.values())
    prefix = "[DRY RUN] Would install" if dry_run else "Installed"

    parts = []
    for label, n in counts.items():
        if n > 0:
            parts.append(f"{n} {label}(s)")

    if parts:
        ok(f"{prefix} {total} item(s): {', '.join(parts)}")
    else:
        warn("Nothing was installed")
        return

    # MCP server notice
    unique_mcps = sorted(set(mcps))
    if unique_mcps:
        print()
        print(f"  {C.BOLD}{C.MAGENTA}MCP servers required:{C.NC}")
        print(f"  {C.DIM}Configure these in your project to use all features:{C.NC}")
        for mcp in unique_mcps:
            print(f"    {C.MAGENTA}*{C.NC} {mcp}")
        print()


def cmd_install_all(
    data: dict, repo_root: Path,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    header()
    label = target_cli if target_cli != "both" else "Claude Code + Codex CLI"
    print(f"  Installing all items for {C.BOLD}{label}{C.NC}")
    print(f"  Target: {C.BOLD}{target_dir}{C.NC}")
    print()

    all_mcps: List[str] = []
    counts: Dict[str, int] = {}

    for t, label in [("agent", "agent"), ("command", "command"), ("skill", "skill")]:
        section(f"{label.title()}s")
        n, mcps = _install_by_type(data, repo_root, t, target_cli, target_dir, dry_run)
        counts[label] = n
        all_mcps.extend(mcps)
        print()

    _print_summary(counts, all_mcps, dry_run)


def cmd_install_type(
    data: dict, repo_root: Path, item_type: str,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    header()
    section(f"{item_type.title()}s")
    n, mcps = _install_by_type(data, repo_root, item_type, target_cli, target_dir, dry_run)
    _print_summary({item_type: n}, mcps, dry_run)


def cmd_install_item(
    data: dict, repo_root: Path, item_id: str,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    header()
    installed, mcps = _install_item(data, repo_root, item_id, target_cli, target_dir, dry_run)
    if installed:
        _print_summary({"item": 1}, mcps, dry_run)


def cmd_install_category(
    data: dict, repo_root: Path, category: str,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    header()
    section(f"Category: {category}")
    n, mcps = _install_by_category(data, repo_root, category, target_cli, target_dir, dry_run)
    _print_summary({"item": n}, mcps, dry_run)


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="install.py",
        description="AI Agents Marketplace — install agents, commands, and skills for Claude Code and Codex CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
{C.BOLD}Examples:{C.NC}
  python3 install.py --list                           Browse all items
  python3 install.py --search security                Search by keyword
  python3 install.py --info agent-bug-detector        Show item details
  python3 install.py --all --target-dir ~/my-project  Install everything
  python3 install.py --all --cli claude               Install for Claude Code only
  python3 install.py --agents                         Install all agents
  python3 install.py --item skill-worktree            Install one item
  python3 install.py --category code-review           Install a category
  python3 install.py --all --dry-run                  Preview only

{C.BOLD}One-liner remote install:{C.NC}
  {C.DIM}# macOS / Linux{C.NC}
  python3 <(curl -fsSL https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py) --all

  {C.DIM}# Windows PowerShell{C.NC}
  Invoke-WebRequest https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py -OutFile install.py; python install.py --all

{C.BOLD}Item IDs:{C.NC}
  Pattern: {{type}}-{{name}} — e.g. agent-bug-detector, cmd-pr-review, skill-worktree
  Use --list to see all IDs.
""",
    )

    # Actions (mutually exclusive)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--all", action="store_true", help="Install all items")
    actions.add_argument("--agents", action="store_true", help="Install all agents")
    actions.add_argument("--commands", action="store_true", help="Install all commands")
    actions.add_argument("--skills", action="store_true", help="Install all skills")
    actions.add_argument("--item", metavar="ID", help="Install a specific item by ID")
    actions.add_argument("--category", metavar="CAT", help="Install all items in a category")
    actions.add_argument("--list", action="store_true", help="List all available items")
    actions.add_argument("--list-categories", action="store_true", help="List categories")
    actions.add_argument("--search", metavar="QUERY", help="Search items by keyword")
    actions.add_argument("--info", metavar="ID", help="Show detailed info about an item")

    # Options
    parser.add_argument("--cli", choices=["claude", "codex", "both"], default="both",
                        help="Target CLI: claude, codex, or both (default: both)")
    parser.add_argument("--target-dir", default=".",
                        help="Target project directory (default: current directory)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview what would be installed without copying files")
    parser.add_argument("--version", action="version",
                        version=f"%(prog)s {__version__}")

    args = parser.parse_args()

    # Load marketplace data (always needed)
    marketplace_path = find_marketplace_json()
    data = load_marketplace(marketplace_path)

    # Read-only actions (don't need repo)
    if args.list:
        cmd_list(data)
        return
    if args.list_categories:
        cmd_categories(data)
        return
    if args.search:
        cmd_search(data, args.search)
        return
    if args.info:
        cmd_info(data, args.info)
        return

    # Install actions (need repo files)
    needs_install = any([args.all, args.agents, args.commands, args.skills, args.item, args.category])
    if not needs_install:
        parser.print_help()
        return

    repo_root = find_repo_root()
    target_dir = Path(args.target_dir).resolve()

    if args.all:
        cmd_install_all(data, repo_root, args.cli, target_dir, args.dry_run)
    elif args.agents:
        cmd_install_type(data, repo_root, "agent", args.cli, target_dir, args.dry_run)
    elif args.commands:
        cmd_install_type(data, repo_root, "command", args.cli, target_dir, args.dry_run)
    elif args.skills:
        cmd_install_type(data, repo_root, "skill", args.cli, target_dir, args.dry_run)
    elif args.item:
        cmd_install_item(data, repo_root, args.item, args.cli, target_dir, args.dry_run)
    elif args.category:
        cmd_install_category(data, repo_root, args.category, args.cli, target_dir, args.dry_run)


if __name__ == "__main__":
    main()
