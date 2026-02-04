#!/usr/bin/env bash
#
# Git Worktree with Gitignored Files Sync
# Creates a git worktree and copies important gitignored files
#

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Blacklist of heavy directories (never copy these)
BLACKLIST=(
    "node_modules"
    ".venv"
    "venv"
    "__pycache__"
    ".cache"
    "dist"
    "build"
    ".git"
    ".tox"
    ".pytest_cache"
    ".mypy_cache"
    "coverage"
    ".next"
    ".nuxt"
    "vendor"
    ".terraform"
    "target"
    ".gradle"
    ".m2"
    "*.egg-info"
)

# Function to check if path matches blacklist
is_blacklisted() {
    local path="$1"
    local basename=$(basename "$path")

    for pattern in "${BLACKLIST[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to format file size
format_size() {
    local size=$1
    if (( size < 1024 )); then
        echo "${size} B"
    elif (( size < 1048576 )); then
        echo "$(( size / 1024 )) KB"
    else
        echo "$(( size / 1048576 )) MB"
    fi
}

# Print usage
usage() {
    echo "Usage: $0 <worktree-path> [branch]"
    echo ""
    echo "Arguments:"
    echo "  worktree-path  Path where the worktree will be created"
    echo "  branch         Branch name (optional, defaults to current branch)"
    echo ""
    echo "Example:"
    echo "  $0 ../my-feature feature/auth"
    echo "  $0 /tmp/worktree-test"
    exit 1
}

# Main script
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        usage
    fi

    local worktree_path="$1"
    local branch="${2:-}"

    # Step 1: Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository${NC}"
        exit 1
    fi

    local source_dir=$(git rev-parse --show-toplevel)
    echo -e "${BLUE}Source repository:${NC} $source_dir"

    # Step 2: Get current branch if not specified
    if [[ -z "$branch" ]]; then
        branch=$(git branch --show-current)
        if [[ -z "$branch" ]]; then
            echo -e "${RED}Error: Not on any branch (detached HEAD) and no branch specified${NC}"
            exit 1
        fi
    fi
    echo -e "${BLUE}Branch:${NC} $branch"

    # Step 3: Resolve worktree path (macOS compatible)
    if [[ "$worktree_path" != /* ]]; then
        worktree_path="$(pwd)/$worktree_path"
    fi
    # Normalize path without requiring it to exist (macOS compatible)
    worktree_path=$(python3 -c "import os; print(os.path.normpath(os.path.abspath('$worktree_path')))")
    echo -e "${BLUE}Worktree path:${NC} $worktree_path"

    # Step 4: Check if path exists
    if [[ -e "$worktree_path" ]]; then
        echo -e "${RED}Error: Path already exists: $worktree_path${NC}"
        echo -e "${YELLOW}Suggestion: Try a different path like ${worktree_path}-2${NC}"
        exit 1
    fi

    # Step 5: Check if branch exists
    local branch_exists=false
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        branch_exists=true
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        branch_exists=true
    fi

    # Step 6: Create worktree
    echo ""
    echo -e "${BLUE}Creating git worktree...${NC}"

    if $branch_exists; then
        if ! git worktree add "$worktree_path" "$branch" 2>&1; then
            echo -e "${RED}Error: Failed to create worktree${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Branch '$branch' does not exist. Creating new branch...${NC}"
        if ! git worktree add -b "$branch" "$worktree_path" 2>&1; then
            echo -e "${RED}Error: Failed to create worktree with new branch${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}Worktree created successfully${NC}"

    # Step 7: Parse .gitignore and find files to copy
    local gitignore_file="$source_dir/.gitignore"
    local files_to_copy=()
    local skipped_dirs=()
    local total_size=0

    if [[ -f "$gitignore_file" ]]; then
        echo ""
        echo -e "${BLUE}Scanning gitignored files...${NC}"

        # Read gitignore and find matching files
        while IFS= read -r pattern || [[ -n "$pattern" ]]; do
            # Skip comments and empty lines
            [[ "$pattern" =~ ^#.*$ ]] && continue
            [[ -z "$pattern" ]] && continue
            # Skip negation patterns
            [[ "$pattern" =~ ^!.*$ ]] && continue

            # Remove leading/trailing whitespace
            pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -z "$pattern" ]] && continue

            # Find matching files
            local found_files
            found_files=$(find "$source_dir" -name "$pattern" 2>/dev/null || true)

            while IFS= read -r file; do
                [[ -z "$file" ]] && continue

                # Check if file is in a blacklisted directory
                local rel_path="${file#$source_dir/}"
                local skip=false

                for part in $(echo "$rel_path" | tr '/' '\n'); do
                    if is_blacklisted "$part"; then
                        skip=true
                        if [[ ! " ${skipped_dirs[*]} " =~ " $part " ]]; then
                            skipped_dirs+=("$part")
                        fi
                        break
                    fi
                done

                if $skip; then
                    continue
                fi

                # Check if it's a regular file (not directory)
                if [[ -f "$file" ]]; then
                    # Skip files larger than 10MB
                    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                    if (( file_size > 10485760 )); then
                        echo -e "${YELLOW}  Skipping large file: $rel_path ($(format_size $file_size))${NC}"
                        continue
                    fi

                    files_to_copy+=("$file")
                    total_size=$((total_size + file_size))
                fi
            done <<< "$found_files"
        done < "$gitignore_file"

        # Also explicitly look for common config files
        local common_configs=(
            ".env"
            ".env.local"
            ".env.development"
            ".env.development.local"
            ".env.test"
            ".env.test.local"
            ".env.production.local"
            ".claude/settings.local.json"
            "config/local.yaml"
            "config/local.yml"
            "config/local.json"
        )

        for config in "${common_configs[@]}"; do
            local config_path="$source_dir/$config"
            if [[ -f "$config_path" ]]; then
                # Check if already in list
                local already_added=false
                for f in "${files_to_copy[@]}"; do
                    if [[ "$f" == "$config_path" ]]; then
                        already_added=true
                        break
                    fi
                done

                if ! $already_added; then
                    local file_size=$(stat -f%z "$config_path" 2>/dev/null || stat -c%s "$config_path" 2>/dev/null || echo "0")
                    files_to_copy+=("$config_path")
                    total_size=$((total_size + file_size))
                fi
            fi
        done
    else
        echo -e "${YELLOW}No .gitignore found, skipping file sync${NC}"
    fi

    # Step 8: Copy files
    local copied_count=0
    if [[ ${#files_to_copy[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Copying gitignored files...${NC}"

        for file in "${files_to_copy[@]}"; do
            local rel_path="${file#$source_dir/}"
            local dest_path="$worktree_path/$rel_path"
            local dest_dir=$(dirname "$dest_path")

            # Create parent directory
            mkdir -p "$dest_dir"

            # Copy file preserving permissions
            if cp -p "$file" "$dest_path" 2>/dev/null; then
                local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                echo -e "  ${GREEN}+${NC} $rel_path ($(format_size $file_size))"
                copied_count=$((copied_count + 1))
            else
                echo -e "  ${RED}x${NC} Failed to copy: $rel_path"
            fi
        done
    fi

    # Step 9: Generate report
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Git Worktree Created Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Worktree Details:${NC}"
    echo "  Path:   $worktree_path"
    echo "  Branch: $branch"
    echo "  Source: $source_dir"
    echo ""

    if [[ $copied_count -gt 0 ]]; then
        echo -e "${BLUE}Copied Files:${NC}"
        echo "  Total: $copied_count files, $(format_size $total_size)"
    else
        echo -e "${YELLOW}No gitignored files were copied${NC}"
    fi

    if [[ ${#skipped_dirs[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Excluded (heavy directories):${NC}"
        for dir in "${skipped_dirs[@]}"; do
            echo "  - $dir/ (skipped)"
        done
    fi

    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. cd $worktree_path"
    echo "  2. Install dependencies if needed:"
    echo "     - Node.js: npm install / yarn / pnpm install"
    echo "     - Python: pip install -r requirements.txt / poetry install"
    echo "     - Go: go mod download"
    echo "  3. Start working on your changes"
}

main "$@"
