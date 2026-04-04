#!/usr/bin/env python3
"""
AI Agents Marketplace - Cross-Platform Installer

Works on macOS, Linux, and Windows. Requires only Python 3.7+ (no external dependencies).

Usage:
    # Remote install (one-liner)
    python3 <(curl -fsSL https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py) --all

    # Local install
    python3 marketplace/install.py --all --cli claude --target-dir ~/my-project

    # List / search
    python3 marketplace/install.py --list
    python3 marketplace/install.py --search security
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

__version__ = "1.0.0"

REPO_URL = "https://github.com/rouksonix/claude-code-octopus.git"
REPO_ARCHIVE_URL = "https://github.com/rouksonix/claude-code-octopus/archive/refs/heads/main.tar.gz"


# ── Colors ──────────────────────────────────────────────────────────────────

class Colors:
    if sys.stdout.isatty() and os.name != "nt":
        RED = "\033[0;31m"
        GREEN = "\033[0;32m"
        YELLOW = "\033[1;33m"
        BLUE = "\033[0;34m"
        CYAN = "\033[0;36m"
        BOLD = "\033[1m"
        NC = "\033[0m"
    else:
        RED = GREEN = YELLOW = BLUE = CYAN = BOLD = NC = ""


def ok(msg):    print(f"{Colors.GREEN}[OK]{Colors.NC} {msg}")
def warn(msg):  print(f"{Colors.YELLOW}[!]{Colors.NC} {msg}")
def err(msg):   print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}", file=sys.stderr)
def info(msg):  print(f"{Colors.BLUE}[i]{Colors.NC} {msg}")

def header():
    print(f"\n{Colors.BOLD}{Colors.CYAN}=== AI Agents Marketplace ==={Colors.NC}\n")


# ── Marketplace Data ────────────────────────────────────────────────────────

def find_marketplace_json(script_dir: Path) -> Path:
    """Find marketplace.json - locally or download it."""
    # Check local paths
    candidates = [
        script_dir / "marketplace.json",
        script_dir.parent / "marketplace.json",
        Path.cwd() / "marketplace.json",
    ]
    for p in candidates:
        if p.is_file():
            return p

    # Download from GitHub
    info("marketplace.json not found locally, downloading from GitHub...")
    return download_marketplace_json()


def download_marketplace_json() -> Path:
    """Download marketplace.json to a temp file."""
    import urllib.request
    url = "https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace.json"
    tmp = Path(tempfile.mkdtemp()) / "marketplace.json"
    try:
        urllib.request.urlretrieve(url, tmp)
        return tmp
    except Exception as e:
        err(f"Failed to download marketplace.json: {e}")
        sys.exit(1)


def load_marketplace(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ── Repo Source ─────────────────────────────────────────────────────────────

def find_repo_root(script_dir: Path) -> Path:
    """Find repo root locally, or clone/download it."""
    # Check if we're inside the repo
    candidates = [script_dir.parent, script_dir, Path.cwd()]
    for p in candidates:
        if (p / ".claude").is_dir() and (p / "marketplace.json").is_file():
            return p

    # Need to download
    info("Marketplace repo not found locally. Cloning from GitHub...")
    return clone_repo()


def clone_repo() -> Path:
    """Clone the repo to a temp directory."""
    import subprocess
    tmp_dir = Path(tempfile.mkdtemp()) / "claude-code-octopus"

    # Try git clone first
    try:
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(tmp_dir)],
            check=True, capture_output=True, text=True,
        )
        return tmp_dir
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    # Fallback: download tarball
    info("git not available, downloading archive...")
    return download_archive()


def download_archive() -> Path:
    """Download and extract the repo archive."""
    import tarfile
    import urllib.request

    tmp_dir = Path(tempfile.mkdtemp())
    archive_path = tmp_dir / "repo.tar.gz"

    try:
        urllib.request.urlretrieve(REPO_ARCHIVE_URL, archive_path)
    except Exception as e:
        err(f"Failed to download archive: {e}")
        sys.exit(1)

    with tarfile.open(archive_path, "r:gz") as tar:
        tar.extractall(tmp_dir)

    # Find extracted directory
    for child in tmp_dir.iterdir():
        if child.is_dir() and child.name.startswith("claude-code-octopus"):
            return child

    err("Failed to find repo in archive")
    sys.exit(1)


# ── List / Search ───────────────────────────────────────────────────────────

def list_items(data: dict):
    header()
    print(f"{Colors.BOLD}Available Items:{Colors.NC}\n")

    for item_type, label in [("agent", "Agents"), ("command", "Commands"), ("skill", "Skills")]:
        items = [i for i in data["items"] if i["type"] == item_type]
        count = len(items)
        print(f"{Colors.BOLD}{Colors.CYAN}{label} ({count}){Colors.NC}")
        print(f"{Colors.BOLD}{'─' * 60}{Colors.NC}")
        for item in items:
            cli_support = []
            for cli_key, cli_name in [("claude-code", "CC"), ("codex", "Codex")]:
                if item.get("compatibility", {}).get(cli_key, {}).get("supported"):
                    cli_support.append(cli_name)
            support_str = ", ".join(cli_support)
            print(f"  {item['id']:<45} [{support_str}]")
            print(f"    {item['description']}")
        print()

    stats = data.get("stats", {})
    print(f"{Colors.BOLD}Total: {stats.get('total', '?')} items{Colors.NC}")
    print(f"  Claude Code: {stats.get('claude_code_supported', '?')} supported")
    print(f"  Codex CLI:   {stats.get('codex_supported', '?')} supported")


def search_items(data: dict, query: str):
    header()
    print(f"Search results for: {Colors.BOLD}{query}{Colors.NC}\n")

    q = query.lower()
    found = 0
    for item in data["items"]:
        name_match = q in item.get("name", "").lower()
        desc_match = q in item.get("description", "").lower()
        tag_match = any(q in t.lower() for t in item.get("tags", []))

        if name_match or desc_match or tag_match:
            found += 1
            print(f"  [{item['type']}] {Colors.BOLD}{item['id']}{Colors.NC}")
            print(f"    {item['description']}")
            tags = ", ".join(item.get("tags", []))
            print(f"    Tags: {tags}")

            for cli_key in ["claude-code", "codex"]:
                compat = item.get("compatibility", {}).get(cli_key, {})
                if compat.get("supported"):
                    inv = compat.get("invocation", compat.get("path", ""))
                    print(f"    {cli_key}: {inv}")
            print()

    if not found:
        warn(f"No items found matching '{query}'")


def list_categories(data: dict):
    header()
    print(f"{Colors.BOLD}Categories:{Colors.NC}\n")
    for section, cats in data.get("categories", {}).items():
        print(f"{Colors.BOLD}{Colors.CYAN}{section.title()}{Colors.NC}")
        for key, val in cats.items():
            icon = val.get("icon", "")
            label = val.get("label", key)
            desc = val.get("description", "")
            print(f"  {key:<25} {icon} {label}: {desc}")
        print()


# ── Install ─────────────────────────────────────────────────────────────────

def copy_item(repo_root: Path, src: str, dst: Path, name: str, dry_run: bool) -> bool:
    src_path = repo_root / src

    if dry_run:
        info(f"[DRY RUN] Would copy: {src} -> {dst}")
        return True

    dst.parent.mkdir(parents=True, exist_ok=True)

    if src_path.is_dir():
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src_path, dst)
        ok(f"Installed {name} -> {dst}")
        return True
    elif src_path.is_file():
        shutil.copy2(src_path, dst)
        ok(f"Installed {name} -> {dst}")
        return True
    else:
        err(f"Source not found: {src_path}")
        return False


def install_item(
    data: dict, repo_root: Path, item_id: str,
    target_cli: str, target_dir: Path, dry_run: bool,
) -> bool:
    item = next((i for i in data["items"] if i["id"] == item_id), None)
    if not item:
        err(f"Item not found: {item_id}")
        return False

    display = item.get("displayName", item["name"])
    installed = False

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
        if copy_item(repo_root, path, dst, f"{display} ({cli_key})", dry_run):
            installed = True

    return installed


def install_by_type(
    data: dict, repo_root: Path, item_type: str,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    items = [i for i in data["items"] if i["type"] == item_type]
    count = 0
    for item in items:
        if install_item(data, repo_root, item["id"], target_cli, target_dir, dry_run):
            count += 1
    info(f"Installed {count} {item_type}(s)")


def install_all(
    data: dict, repo_root: Path,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    header()
    print(f"Installing all items for: {Colors.BOLD}{target_cli}{Colors.NC}")
    print(f"Target directory: {Colors.BOLD}{target_dir}{Colors.NC}\n")

    for t in ("agent", "command", "skill"):
        install_by_type(data, repo_root, t, target_cli, target_dir, dry_run)

    print()
    ok("Installation complete!")


def install_by_category(
    data: dict, repo_root: Path, category: str,
    target_cli: str, target_dir: Path, dry_run: bool,
):
    items = [i for i in data["items"] if i.get("category") == category]
    if not items:
        err(f"No items found in category: {category}")
        return

    header()
    print(f"Installing category: {Colors.BOLD}{category}{Colors.NC}\n")

    count = 0
    for item in items:
        if install_item(data, repo_root, item["id"], target_cli, target_dir, dry_run):
            count += 1
    info(f"Installed {count} item(s) from '{category}'")


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="marketplace-install",
        description="AI Agents Marketplace - Install agents, commands, and skills for Claude Code and Codex CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list                           List all available items
  %(prog)s --search security                Search for security items
  %(prog)s --all --target-dir ~/my-project  Install everything
  %(prog)s --agents --cli claude            Install agents for Claude Code
  %(prog)s --item agent-bug-detector        Install specific item
  %(prog)s --category code-review           Install all code review items
  %(prog)s --all --dry-run                  Preview without installing

One-liner remote install:
  python3 <(curl -fsSL https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py) --all --target-dir .

On Windows (PowerShell):
  irm https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py | python3 - --all --target-dir .
""",
    )

    # Actions
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--all", action="store_true", help="Install all items")
    actions.add_argument("--agents", action="store_true", help="Install all agents")
    actions.add_argument("--commands", action="store_true", help="Install all commands")
    actions.add_argument("--skills", action="store_true", help="Install all skills")
    actions.add_argument("--item", metavar="ID", help="Install specific item by ID")
    actions.add_argument("--category", metavar="CAT", help="Install all items in a category")
    actions.add_argument("--list", action="store_true", help="List all items")
    actions.add_argument("--list-categories", action="store_true", help="List categories")
    actions.add_argument("--search", metavar="QUERY", help="Search items")

    # Options
    parser.add_argument("--cli", choices=["claude", "codex", "both"], default="both",
                        help="Target CLI (default: both)")
    parser.add_argument("--target-dir", default=".", help="Target project directory (default: .)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without installing")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    args = parser.parse_args()

    # Find marketplace data
    script_dir = Path(__file__).resolve().parent
    marketplace_json = find_marketplace_json(script_dir)
    data = load_marketplace(marketplace_json)

    # Read-only actions
    if args.list:
        list_items(data)
        return
    if args.list_categories:
        list_categories(data)
        return
    if args.search:
        search_items(data, args.search)
        return

    # Install actions need repo source
    if not any([args.all, args.agents, args.commands, args.skills, args.item, args.category]):
        parser.print_help()
        return

    repo_root = find_repo_root(script_dir)
    target_dir = Path(args.target_dir).resolve()

    if args.all:
        install_all(data, repo_root, args.cli, target_dir, args.dry_run)
    elif args.agents:
        header()
        install_by_type(data, repo_root, "agent", args.cli, target_dir, args.dry_run)
    elif args.commands:
        header()
        install_by_type(data, repo_root, "command", args.cli, target_dir, args.dry_run)
    elif args.skills:
        header()
        install_by_type(data, repo_root, "skill", args.cli, target_dir, args.dry_run)
    elif args.item:
        header()
        install_item(data, repo_root, args.item, args.cli, target_dir, args.dry_run)
    elif args.category:
        install_by_category(data, repo_root, args.category, args.cli, target_dir, args.dry_run)


if __name__ == "__main__":
    main()
