#!/usr/bin/env bash
#
# Git Worktree with Gitignored Files Sync
# Creates a git worktree and copies important gitignored files
#
# Compatible with bash 3.2+ (macOS default)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
readonly MAX_FILE_SIZE_BYTES=10485760  # 10MB

# Car brands for random branch naming
CAR_BRANDS=(
    "toyota" "honda" "ford" "chevrolet" "bmw" "mercedes" "audi" "volkswagen"
    "porsche" "ferrari" "lamborghini" "maserati" "jaguar" "lexus" "infiniti"
    "acura" "mazda" "subaru" "nissan" "hyundai" "kia" "volvo" "tesla" "rivian"
    "bentley" "rollsroyce" "aston" "mclaren" "bugatti" "pagani" "koenigsegg"
    "alpine" "lotus" "morgan" "mini" "fiat" "alfa" "lancia" "peugeot" "renault"
    "citroen" "skoda" "seat" "opel" "saab" "lada" "dacia" "suzuki" "mitsubishi"
)

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

# Global variables for tracking (bash 3.x compatible - no associative arrays)
SEEN_FILES=""
SEEN_DIRS=""

# Cleanup function for partial failures
cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && -n "${WORKTREE_PATH_FOR_CLEANUP:-}" && -d "$WORKTREE_PATH_FOR_CLEANUP" ]]; then
        echo -e "${YELLOW}Cleaning up partial worktree at: $WORKTREE_PATH_FOR_CLEANUP${NC}"
        git worktree remove --force "$WORKTREE_PATH_FOR_CLEANUP" 2>/dev/null || rm -rf "$WORKTREE_PATH_FOR_CLEANUP"
    fi
    exit $exit_code
}

# Function to check if item exists in newline-separated list (bash 3.x compatible)
is_in_list() {
    local item="$1"
    local list="$2"
    echo "$list" | grep -qxF "$item" 2>/dev/null
}

# Function to add item to newline-separated list
add_to_list() {
    local item="$1"
    local list="$2"
    if [[ -z "$list" ]]; then
        echo "$item"
    else
        printf '%s\n%s' "$list" "$item"
    fi
}

# Function to get random car brand
get_random_car() {
    local index=$((RANDOM % ${#CAR_BRANDS[@]}))
    echo "${CAR_BRANDS[$index]}"
}

# Function to check if path matches blacklist
is_blacklisted() {
    local path="$1"
    local bname
    bname=$(basename "$path")

    for pattern in "${BLACKLIST[@]}"; do
        if [[ "$bname" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get file size (cross-platform)
get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
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

# Function to normalize path (pure bash, no python)
normalize_path() {
    local path="$1"
    local result=""
    local parts=""
    local normalized=""
    local part=""

    # Handle absolute vs relative
    if [[ "$path" == /* ]]; then
        result="/"
    fi

    # Split path into parts and process
    local old_ifs="$IFS"
    IFS='/'
    for part in $path; do
        case "$part" in
            ""|".")
                # Skip empty and current dir
                ;;
            "..")
                # Go up one level - remove last component
                normalized="${normalized%/*}"
                ;;
            *)
                if [[ -z "$normalized" ]]; then
                    normalized="$part"
                else
                    normalized="$normalized/$part"
                fi
                ;;
        esac
    done
    IFS="$old_ifs"

    # Build result
    if [[ "$result" == "/" ]]; then
        result="/$normalized"
    else
        result="$normalized"
    fi

    # Handle empty result
    if [[ -z "$result" ]]; then
        result="."
    fi

    echo "$result"
}

# Function to validate branch name
validate_branch_name() {
    local branch="$1"
    if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid branch name: $branch${NC}"
        echo -e "${YELLOW}Branch names cannot contain spaces, ~, ^, :, ?, *, [, or \\${NC}"
        exit 1
    fi
}

# Print usage
usage() {
    echo "Usage: $0 [worktree-path] [branch]"
    echo ""
    echo "Arguments:"
    echo "  worktree-path  Path where the worktree will be created"
    echo "                 Default: ../worktrees/<repo-name>-<timestamp>"
    echo "  branch         Branch name"
    echo "                 Default: ai-worktree/<car-brand>-<timestamp>"
    echo ""
    echo "Example:"
    echo "  $0                                    # Auto-generate path and branch"
    echo "  $0 ../my-feature                      # Auto-generate branch only"
    echo "  $0 ../my-feature feature/auth         # Specify both"
    echo "  $0 /tmp/worktree-test"
}

# Main script
main() {
    # Handle --help flag
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        usage
        exit 0
    fi

    local worktree_path="${1:-}"
    local branch="${2:-}"

    # Step 1: Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository${NC}"
        exit 1
    fi

    local source_dir
    source_dir=$(git rev-parse --show-toplevel)
    local repo_name
    repo_name=$(basename "$source_dir")
    local timestamp
    timestamp=$(date +%s)

    echo -e "${BLUE}Source repository:${NC} $source_dir"

    # Step 2: Generate default worktree path if not specified
    if [[ -z "$worktree_path" ]]; then
        local worktrees_dir="$source_dir/../worktrees"
        worktree_path="$worktrees_dir/${repo_name}-${timestamp}"
        echo -e "${YELLOW}Using default path:${NC} $worktree_path"
    fi

    # Step 3: Generate default branch name if not specified
    if [[ -z "$branch" ]]; then
        local car_brand
        car_brand=$(get_random_car)
        branch="ai-worktree/${car_brand}-${timestamp}"
        echo -e "${YELLOW}Using generated branch:${NC} $branch"
    fi

    # Step 3.1: Validate branch name
    validate_branch_name "$branch"

    echo -e "${BLUE}Branch:${NC} $branch"

    # Step 4: Resolve worktree path (pure bash, no python injection risk)
    if [[ "$worktree_path" != /* ]]; then
        worktree_path="$(pwd)/$worktree_path"
    fi
    # Normalize path using pure bash function
    worktree_path=$(normalize_path "$worktree_path")
    echo -e "${BLUE}Worktree path:${NC} $worktree_path"

    # Step 5: Check if path exists
    if [[ -e "$worktree_path" ]]; then
        echo -e "${RED}Error: Path already exists: $worktree_path${NC}"
        echo -e "${YELLOW}Suggestion: Try a different path like ${worktree_path}-2${NC}"
        exit 1
    fi

    # Set up cleanup trap for partial failures
    WORKTREE_PATH_FOR_CLEANUP="$worktree_path"
    trap cleanup_on_failure EXIT

    # Step 6: Check if branch exists
    local branch_exists=false
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        branch_exists=true
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        branch_exists=true
    fi

    # Step 7: Create worktree
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

    # Step 8: Parse .gitignore and find files to copy
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

            # Remove leading/trailing whitespace using bash parameter expansion
            pattern="${pattern#"${pattern%%[![:space:]]*}"}"
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            [[ -z "$pattern" ]] && continue

            # Remove trailing slash (gitignore uses it for directories)
            pattern="${pattern%/}"

            # Find matching files
            local found_files
            found_files=$(find "$source_dir" -name "$pattern" 2>/dev/null || true)

            while IFS= read -r file; do
                [[ -z "$file" ]] && continue

                # Check if file is in a blacklisted directory
                local rel_path="${file#"$source_dir"/}"
                local skip=false

                # Split path by / and check each component
                local old_ifs="$IFS"
                IFS='/'
                for part in $rel_path; do
                    if is_blacklisted "$part"; then
                        skip=true
                        if ! is_in_list "$part" "$SEEN_DIRS"; then
                            skipped_dirs+=("$part")
                            SEEN_DIRS=$(add_to_list "$part" "$SEEN_DIRS")
                        fi
                        break
                    fi
                done
                IFS="$old_ifs"

                if $skip; then
                    continue
                fi

                # Check if it's a regular file (not directory)
                if [[ -f "$file" ]]; then
                    # Skip if already added
                    if is_in_list "$file" "$SEEN_FILES"; then
                        continue
                    fi
                    SEEN_FILES=$(add_to_list "$file" "$SEEN_FILES")

                    # Skip files larger than MAX_FILE_SIZE_BYTES
                    local file_size
                    file_size=$(get_file_size "$file")
                    if (( file_size > MAX_FILE_SIZE_BYTES )); then
                        echo -e "${YELLOW}  Skipping large file: $rel_path ($(format_size "$file_size"))${NC}"
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
                if is_in_list "$config_path" "$SEEN_FILES"; then
                    continue
                fi
                SEEN_FILES=$(add_to_list "$config_path" "$SEEN_FILES")

                local file_size
                file_size=$(get_file_size "$config_path")
                files_to_copy+=("$config_path")
                total_size=$((total_size + file_size))
            fi
        done
    else
        echo -e "${YELLOW}No .gitignore found, skipping file sync${NC}"
    fi

    # Step 9: Copy files
    local copied_count=0
    if [[ ${#files_to_copy[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Copying gitignored files...${NC}"

        for file in "${files_to_copy[@]}"; do
            local rel_path="${file#"$source_dir"/}"
            local dest_path="$worktree_path/$rel_path"
            local dest_dir
            dest_dir=$(dirname "$dest_path")

            # Create parent directory
            mkdir -p "$dest_dir"

            # Copy file preserving permissions
            if cp -p "$file" "$dest_path" 2>/dev/null; then
                local file_size
                file_size=$(get_file_size "$file")
                echo -e "  ${GREEN}+${NC} $rel_path ($(format_size "$file_size"))"
                copied_count=$((copied_count + 1))
            else
                echo -e "  ${RED}x${NC} Failed to copy: $rel_path"
            fi
        done
    fi

    # Clear the cleanup trap on success
    WORKTREE_PATH_FOR_CLEANUP=""
    trap - EXIT

    # Step 10: Generate report
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
        echo "  Total: $copied_count files, $(format_size "$total_size")"
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
