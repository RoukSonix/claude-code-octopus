#!/usr/bin/env python3
"""
Git Worktree with Gitignored Files Sync (Universal)
Creates a git worktree and copies important gitignored files

Compatible with Python 3.7+ on macOS, Linux, and Windows
"""

import argparse
import fnmatch
import os
import random
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import List, Set, Tuple

# Constants
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10MB

# Car brands for random branch naming
CAR_BRANDS = [
    "toyota",
    "honda",
    "ford",
    "chevrolet",
    "bmw",
    "mercedes",
    "audi",
    "volkswagen",
    "porsche",
    "ferrari",
    "lamborghini",
    "maserati",
    "jaguar",
    "lexus",
    "infiniti",
    "acura",
    "mazda",
    "subaru",
    "nissan",
    "hyundai",
    "kia",
    "volvo",
    "tesla",
    "rivian",
    "bentley",
    "rollsroyce",
    "aston",
    "mclaren",
    "bugatti",
    "pagani",
    "koenigsegg",
    "alpine",
    "lotus",
    "morgan",
    "mini",
    "fiat",
    "alfa",
    "lancia",
    "peugeot",
    "renault",
    "citroen",
    "skoda",
    "seat",
    "opel",
    "saab",
    "dacia",
    "suzuki",
    "mitsubishi",
]

# Blacklist of heavy directories (never copy these)
BLACKLIST = {
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
    ".cache",
    "dist",
    "build",
    ".git",
    ".tox",
    ".pytest_cache",
    ".mypy_cache",
    "coverage",
    ".next",
    ".nuxt",
    "vendor",
    ".terraform",
    "target",
    ".gradle",
    ".m2",
    "*.egg-info",
}

# Common config files to look for explicitly
COMMON_CONFIGS = [
    ".env",
    ".env.local",
    ".env.development",
    ".env.development.local",
    ".env.test",
    ".env.test.local",
    ".env.production.local",
    ".claude/settings.local.json",
    "config/local.yaml",
    "config/local.yml",
    "config/local.json",
]


class Colors:
    """ANSI color codes for terminal output"""

    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    NC = "\033[0m"  # No Color

    @classmethod
    def disable(cls):
        """Disable colors (for non-terminal output)"""
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = cls.CYAN = cls.MAGENTA = (
            cls.NC
        ) = ""


def print_error(msg: str) -> None:
    """Print error message"""
    print(f"{Colors.RED}Error: {msg}{Colors.NC}")


def print_warn(msg: str) -> None:
    """Print warning message"""
    print(f"{Colors.YELLOW}{msg}{Colors.NC}")


def print_info(msg: str) -> None:
    """Print info message"""
    print(f"{Colors.BLUE}{msg}{Colors.NC}")


def print_success(msg: str) -> None:
    """Print success message"""
    print(f"{Colors.GREEN}{msg}{Colors.NC}")


def run_git_command(args: List[str], check: bool = True) -> Tuple[int, str]:
    """
    Run a git command and return exit code and output

    Args:
        args: List of arguments for git command
        check: If True, raise exception on non-zero exit code

    Returns:
        Tuple of (exit_code, output)
    """
    try:
        result = subprocess.run(
            ["git"] + args, capture_output=True, text=True, check=False
        )
        output = result.stdout.strip() if result.stdout else result.stderr.strip()
        if check and result.returncode != 0:
            raise subprocess.CalledProcessError(
                result.returncode, ["git"] + args, output=output
            )
        return result.returncode, output
    except FileNotFoundError:
        raise RuntimeError("git command not found. Please install git.")


def validate_branch_name(branch: str) -> bool:
    """
    Validate git branch name

    Args:
        branch: Branch name to validate

    Returns:
        True if valid, False otherwise
    """
    try:
        run_git_command(["check-ref-format", "--branch", branch])
        return True
    except subprocess.CalledProcessError:
        return False


def get_random_car() -> str:
    """Get random car brand for branch naming"""
    return random.choice(CAR_BRANDS)


def is_blacklisted(path_part: str) -> bool:
    """
    Check if path part matches blacklist

    Args:
        path_part: Part of path to check

    Returns:
        True if blacklisted
    """
    # Check exact match
    if path_part in BLACKLIST:
        return True
    # Check glob patterns
    for pattern in BLACKLIST:
        if "*" in pattern and fnmatch.fnmatch(path_part, pattern):
            return True
    return False


def format_size(size: int) -> str:
    """
    Format file size in human-readable form

    Args:
        size: Size in bytes

    Returns:
        Formatted string (e.g., "1.5 MB")
    """
    if size < 1024:
        return f"{size} B"
    elif size < 1024 * 1024:
        return f"{size // 1024} KB"
    else:
        return f"{size // (1024 * 1024)} MB"


def find_git_ignored_files(
    source_dir: Path, gitignore_path: Path
) -> Tuple[List[Path], Set[str]]:
    """
    Find files matching patterns in .gitignore

    Args:
        source_dir: Source directory path
        gitignore_path: Path to .gitignore file

    Returns:
        Tuple of (files_to_copy, skipped_dirs)
    """
    files_to_copy: List[Path] = []
    skipped_dirs: Set[str] = set()
    seen_files: Set[Path] = set()

    if not gitignore_path.exists():
        return files_to_copy, skipped_dirs

    print_info("Scanning gitignored files...")

    # Read .gitignore patterns
    patterns: List[str] = []
    try:
        with open(gitignore_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                # Skip comments, empty lines, and negation patterns
                if not line or line.startswith("#") or line.startswith("!"):
                    continue
                # Remove trailing slash (gitignore uses it for directories)
                line = line.rstrip("/")
                # Skip patterns with path separators or double stars (simplified matching)
                if "/" in line or "\\" in line or "**" in line:
                    continue
                patterns.append(line)
    except Exception as e:
        print_warn(f"Warning: Could not read .gitignore: {e}")
        return files_to_copy, skipped_dirs

    # Walk directory tree
    for root, dirs, files in os.walk(source_dir):
        root_path = Path(root)
        rel_root = root_path.relative_to(source_dir)

        # Filter out blacklisted directories
        dirs_to_remove = []
        for d in dirs:
            if is_blacklisted(d):
                skipped_dirs.add(d)
                dirs_to_remove.append(d)
        for d in dirs_to_remove:
            dirs.remove(d)

        # Check files against patterns
        for filename in files:
            # Check if filename matches any pattern
            for pattern in patterns:
                if fnmatch.fnmatch(filename, pattern):
                    file_path = root_path / filename

                    # Skip if already seen
                    if file_path in seen_files:
                        break
                    seen_files.add(file_path)

                    # Check file size
                    try:
                        size = file_path.stat().st_size
                        if size > MAX_FILE_SIZE_BYTES:
                            rel_path = file_path.relative_to(source_dir)
                            print_warn(
                                f"  Skipping large file: {rel_path} ({format_size(size)})"
                            )
                            break
                        files_to_copy.append(file_path)
                    except OSError:
                        pass
                    break

    return files_to_copy, skipped_dirs


def find_common_config_files(source_dir: Path, seen_files: Set[Path]) -> List[Path]:
    """
    Find common config files explicitly

    Args:
        source_dir: Source directory path
        seen_files: Set of already seen file paths

    Returns:
        List of config file paths
    """
    config_files: List[Path] = []

    for config in COMMON_CONFIGS:
        config_path = source_dir / config
        if config_path.exists() and config_path.is_file():
            if config_path not in seen_files:
                config_files.append(config_path)
                seen_files.add(config_path)

    return config_files


def copy_file_with_metadata(src: Path, dst: Path) -> bool:
    """
    Copy file preserving metadata (timestamps, permissions)

    Args:
        src: Source file path
        dst: Destination file path

    Returns:
        True if successful
    """
    try:
        # Ensure parent directory exists
        dst.parent.mkdir(parents=True, exist_ok=True)

        # Copy file
        shutil.copy2(src, dst)
        return True
    except Exception as e:
        print_warn(f"  Failed to copy {src}: {e}")
        return False


def cleanup_on_failure(worktree_path: Path) -> None:
    """Clean up partial worktree on failure"""
    if worktree_path.exists():
        print_warn(f"Cleaning up partial worktree at: {worktree_path}")
        try:
            # Try to remove using git worktree command first
            subprocess.run(
                ["git", "worktree", "remove", "--force", str(worktree_path)],
                capture_output=True,
                check=False,
            )
        except:
            pass

        # Remove directory if still exists
        if worktree_path.exists():
            try:
                shutil.rmtree(worktree_path)
            except:
                pass


def main():
    parser = argparse.ArgumentParser(
        description="Create git worktree with automatic sync of gitignored files"
    )
    parser.add_argument(
        "worktree_path",
        nargs="?",
        help="Path where the worktree will be created (default: ../worktrees/<repo>-<timestamp>)",
    )
    parser.add_argument(
        "branch", nargs="?", help="Branch name (default: ai-worktree/<car>-<timestamp>)"
    )
    parser.add_argument(
        "--no-color", action="store_true", help="Disable colored output"
    )

    args = parser.parse_args()

    # Disable colors if requested or not in terminal
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()

    # Step 1: Validate git repository
    try:
        _, git_dir = run_git_command(["rev-parse", "--git-dir"], check=True)
    except subprocess.CalledProcessError:
        print_error("Not a git repository")
        sys.exit(1)

    # Get repository info
    _, source_dir_str = run_git_command(["rev-parse", "--show-toplevel"])
    source_dir = Path(source_dir_str).resolve()
    repo_name = source_dir.name
    timestamp = int(time.time())

    print_info(f"Source repository: {source_dir}")

    # Step 2: Generate default worktree path if not specified
    worktree_path_str = args.worktree_path
    if not worktree_path_str:
        worktrees_dir = source_dir.parent / "worktrees"
        worktree_path = worktrees_dir / f"{repo_name}-{timestamp}"
        print_warn(f"Using default path: {worktree_path}")
    else:
        worktree_path = Path(worktree_path_str).resolve()

    # Step 3: Generate default branch name if not specified
    branch = args.branch
    if not branch:
        car_brand = get_random_car()
        branch = f"ai-worktree/{car_brand}-{timestamp}"
        print_warn(f"Using generated branch: {branch}")

    # Step 3.1: Validate branch name
    if not validate_branch_name(branch):
        print_error(f"Invalid branch name: {branch}")
        print_warn("Branch names cannot contain spaces, ~, ^, :, ?, *, [, or \\")
        sys.exit(1)

    print_info(f"Branch: {branch}")
    print_info(f"Worktree path: {worktree_path}")

    # Step 4: Check if path exists
    if worktree_path.exists():
        print_error(f"Path already exists: {worktree_path}")
        print_warn(f"Suggestion: Try a different path like {worktree_path}-2")
        sys.exit(1)

    try:
        # Step 5: Check if branch exists
        branch_exists = False
        try:
            run_git_command(["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"])
            branch_exists = True
        except subprocess.CalledProcessError:
            try:
                run_git_command(
                    ["show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch}"]
                )
                branch_exists = True
            except subprocess.CalledProcessError:
                pass

        # Step 6: Create worktree
        print()
        print_info("Creating git worktree...")

        if branch_exists:
            run_git_command(["worktree", "add", str(worktree_path), branch])
        else:
            print_warn(f"Branch '{branch}' does not exist. Creating new branch...")
            run_git_command(["worktree", "add", "-b", branch, str(worktree_path)])

        print_success("Worktree created successfully")

        # Step 7: Parse .gitignore and find files to copy
        gitignore_path = source_dir / ".gitignore"
        files_to_copy: List[Path] = []
        skipped_dirs: Set[str] = set()
        seen_files: Set[Path] = set()
        total_size = 0

        if gitignore_path.exists():
            gitignore_files, skipped_dirs = find_git_ignored_files(
                source_dir, gitignore_path
            )
            files_to_copy.extend(gitignore_files)
            for f in gitignore_files:
                seen_files.add(f)
                try:
                    total_size += f.stat().st_size
                except:
                    pass

        # Step 8: Also explicitly look for common config files
        config_files = find_common_config_files(source_dir, seen_files)
        files_to_copy.extend(config_files)
        for f in config_files:
            try:
                total_size += f.stat().st_size
            except:
                pass

        # Step 9: Copy files
        copied_count = 0
        if files_to_copy:
            print()
            print_info("Copying gitignored files...")

            for file_path in files_to_copy:
                rel_path = file_path.relative_to(source_dir)
                dest_path = worktree_path / rel_path

                if copy_file_with_metadata(file_path, dest_path):
                    try:
                        size = file_path.stat().st_size
                        print(
                            f"  {Colors.GREEN}+{Colors.NC} {rel_path} ({format_size(size)})"
                        )
                        copied_count += 1
                    except:
                        print(f"  {Colors.GREEN}+{Colors.NC} {rel_path}")
                        copied_count += 1

        # Step 10: Generate report
        print()
        print_success("=" * 40)
        print_success("Git Worktree Created Successfully")
        print_success("=" * 40)
        print()
        print_info("Worktree Details:")
        print(f"  Path:   {worktree_path}")
        print(f"  Branch: {branch}")
        print(f"  Source: {source_dir}")
        print()

        if copied_count > 0:
            print_info("Copied Files:")
            print(f"  Total: {copied_count} files, {format_size(total_size)}")
        else:
            print_warn("No gitignored files were copied")

        if skipped_dirs:
            print()
            print_info("Excluded (heavy directories):")
            for dir_name in sorted(skipped_dirs):
                print(f"  - {dir_name}/ (skipped)")

        print()
        print_info("Next Steps:")
        print(f"  1. cd {worktree_path}")
        print("  2. Install dependencies if needed:")
        print("     - Node.js: npm install / yarn / pnpm install")
        print("     - Python: pip install -r requirements.txt / poetry install")
        print("     - .NET: dotnet restore")
        print("     - Go: go mod download")
        print("  3. Start working on your changes")

    except subprocess.CalledProcessError as e:
        print_error(str(e))
        cleanup_on_failure(worktree_path)
        sys.exit(1)
    except KeyboardInterrupt:
        print_warn("\nOperation cancelled by user")
        cleanup_on_failure(worktree_path)
        sys.exit(1)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        cleanup_on_failure(worktree_path)
        sys.exit(1)


if __name__ == "__main__":
    main()
