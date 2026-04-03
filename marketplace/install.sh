#!/usr/bin/env bash
# AI Agents Marketplace - Installer
# Installs agents, commands, and skills from the marketplace into your project.
#
# Usage:
#   ./marketplace/install.sh [options]
#
# Options:
#   --all                Install everything (agents + commands + skills)
#   --agents             Install all agents (Claude Code only)
#   --commands           Install all commands
#   --skills             Install all skills
#   --item ID            Install a specific item by ID
#   --cli TARGET         Target CLI: claude, codex, or both (default: both)
#   --list               List all available items
#   --list-categories    List categories
#   --search QUERY       Search items by name, tag, or description
#   --dry-run            Show what would be installed without copying
#   --help               Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_JSON="$REPO_ROOT/marketplace.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
TARGET_CLI="both"
DRY_RUN=false
ACTION=""
ITEM_ID=""
SEARCH_QUERY=""
TARGET_DIR="."

print_header() {
    echo -e "\n${BOLD}${CYAN}=== AI Agents Marketplace ===${NC}\n"
}

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_info()    { echo -e "${BLUE}[i]${NC} $1"; }

check_deps() {
    if ! command -v jq &>/dev/null; then
        print_error "jq is required. Install it: brew install jq / apt install jq"
        exit 1
    fi
    if [[ ! -f "$MARKETPLACE_JSON" ]]; then
        print_error "marketplace.json not found at $MARKETPLACE_JSON"
        exit 1
    fi
}

list_items() {
    print_header
    echo -e "${BOLD}Available Items:${NC}\n"

    echo -e "${BOLD}${CYAN}Agents (19)${NC}"
    echo -e "${BOLD}-------------------------------------------${NC}"
    jq -r '.items[] | select(.type == "agent") | "  \(.id) — \(.description)"' "$MARKETPLACE_JSON"

    echo -e "\n${BOLD}${CYAN}Commands (20)${NC}"
    echo -e "${BOLD}-------------------------------------------${NC}"
    jq -r '.items[] | select(.type == "command") | "  \(.id) — \(.description)"' "$MARKETPLACE_JSON"

    echo -e "\n${BOLD}${CYAN}Skills (4)${NC}"
    echo -e "${BOLD}-------------------------------------------${NC}"
    jq -r '.items[] | select(.type == "skill") | "  \(.id) — \(.description)"' "$MARKETPLACE_JSON"

    echo -e "\n${BOLD}Total: $(jq '.stats.total' "$MARKETPLACE_JSON") items${NC}"
    echo -e "  Claude Code: $(jq '.stats.claude_code_supported' "$MARKETPLACE_JSON") supported"
    echo -e "  Codex CLI:   $(jq '.stats.codex_supported' "$MARKETPLACE_JSON") supported"
}

list_categories() {
    print_header
    echo -e "${BOLD}Categories:${NC}\n"
    for section in agents commands skills; do
        echo -e "${BOLD}${CYAN}${section^}${NC}"
        jq -r ".categories.${section} | to_entries[] | \"  \(.key) — \(.value.icon) \(.value.label): \(.value.description)\"" "$MARKETPLACE_JSON"
        echo
    done
}

search_items() {
    local query="$1"
    print_header
    echo -e "Search results for: ${BOLD}${query}${NC}\n"

    local results
    results=$(jq -r --arg q "$query" '
        .items[] |
        select(
            (.name | ascii_downcase | contains($q | ascii_downcase)) or
            (.description | ascii_downcase | contains($q | ascii_downcase)) or
            (.tags | map(ascii_downcase) | any(contains($q | ascii_downcase)))
        ) |
        "  [\(.type)] \(.id)\n    \(.description)\n    Tags: \(.tags | join(", "))\n"
    ' "$MARKETPLACE_JSON")

    if [[ -z "$results" ]]; then
        print_warn "No items found matching '$query'"
    else
        echo "$results"
    fi
}

copy_item() {
    local src="$1"
    local dst="$2"
    local item_name="$3"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would copy: $src -> $dst"
        return
    fi

    local dst_dir
    dst_dir="$(dirname "$dst")"
    mkdir -p "$dst_dir"

    if [[ -d "$REPO_ROOT/$src" ]]; then
        cp -r "$REPO_ROOT/$src" "$dst"
        print_success "Installed $item_name -> $dst"
    elif [[ -f "$REPO_ROOT/$src" ]]; then
        cp "$REPO_ROOT/$src" "$dst"
        print_success "Installed $item_name -> $dst"
    else
        print_error "Source not found: $src"
        return 1
    fi
}

install_item_by_id() {
    local id="$1"
    local target="$2"
    local target_dir="$3"

    local item
    item=$(jq -r --arg id "$id" '.items[] | select(.id == $id)' "$MARKETPLACE_JSON")

    if [[ -z "$item" || "$item" == "null" ]]; then
        print_error "Item not found: $id"
        return 1
    fi

    local name display_name type
    name=$(echo "$item" | jq -r '.name')
    display_name=$(echo "$item" | jq -r '.displayName')
    type=$(echo "$item" | jq -r '.type')

    for cli in claude-code codex; do
        if [[ "$target" != "both" && "$target" != "${cli//-code/}" ]]; then
            continue
        fi

        local supported path
        supported=$(echo "$item" | jq -r ".compatibility.\"$cli\".supported")
        path=$(echo "$item" | jq -r ".compatibility.\"$cli\".path")

        if [[ "$supported" != "true" || "$path" == "null" ]]; then
            if [[ "$target" != "both" ]]; then
                print_warn "$display_name is not supported for $cli"
            fi
            continue
        fi

        local dest="${target_dir}/${path}"
        copy_item "$path" "$dest" "$display_name ($cli)"
    done
}

install_by_type() {
    local type_filter="$1"
    local target="$2"
    local target_dir="$3"

    local ids
    ids=$(jq -r --arg t "$type_filter" '.items[] | select(.type == $t) | .id' "$MARKETPLACE_JSON")

    local count=0
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        install_item_by_id "$id" "$target" "$target_dir" && ((count++)) || true
    done <<< "$ids"

    print_info "Installed $count ${type_filter}(s)"
}

install_all() {
    local target="$1"
    local target_dir="$2"

    print_header
    echo -e "Installing all items for: ${BOLD}${target}${NC}\n"

    install_by_type "agent" "$target" "$target_dir"
    install_by_type "command" "$target" "$target_dir"
    install_by_type "skill" "$target" "$target_dir"

    echo
    print_success "Installation complete!"
}

show_help() {
    print_header
    cat << 'EOF'
Usage: ./marketplace/install.sh [options]

Install agents, commands, and skills from the AI Agents Marketplace.

OPTIONS:
  --all                Install everything (agents + commands + skills)
  --agents             Install all agents (Claude Code only)
  --commands           Install all commands
  --skills             Install all skills
  --item ID            Install a specific item by marketplace ID
  --cli TARGET         Target CLI: claude, codex, or both (default: both)
  --target-dir DIR     Target project directory (default: current directory)
  --list               List all available items
  --list-categories    List available categories
  --search QUERY       Search items by name, tag, or description
  --dry-run            Preview what would be installed
  --help               Show this help

EXAMPLES:
  # List everything available
  ./marketplace/install.sh --list

  # Search for security-related items
  ./marketplace/install.sh --search security

  # Install all items for Claude Code
  ./marketplace/install.sh --all --cli claude

  # Install just the worktree skill for both CLIs
  ./marketplace/install.sh --item skill-worktree

  # Install all commands for Codex CLI to a specific project
  ./marketplace/install.sh --commands --cli codex --target-dir ~/my-project

  # Preview installation without copying
  ./marketplace/install.sh --all --dry-run

ITEM IDs:
  Items follow the pattern: {type}-{name}
  Examples: agent-bug-detector, cmd-pr-review, skill-worktree

  Use --list to see all available IDs.
EOF
}

# --- Main ---

check_deps

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)        ACTION="all"; shift ;;
        --agents)     ACTION="agents"; shift ;;
        --commands)   ACTION="commands"; shift ;;
        --skills)     ACTION="skills"; shift ;;
        --item)       ACTION="item"; ITEM_ID="$2"; shift 2 ;;
        --cli)        TARGET_CLI="$2"; shift 2 ;;
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --list)       ACTION="list"; shift ;;
        --list-categories) ACTION="list-categories"; shift ;;
        --search)     ACTION="search"; SEARCH_QUERY="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --help|-h)    show_help; exit 0 ;;
        *)            print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    show_help
    exit 0
fi

case "$ACTION" in
    list)            list_items ;;
    list-categories) list_categories ;;
    search)          search_items "$SEARCH_QUERY" ;;
    all)             install_all "$TARGET_CLI" "$TARGET_DIR" ;;
    agents)          print_header; install_by_type "agent" "$TARGET_CLI" "$TARGET_DIR" ;;
    commands)        print_header; install_by_type "command" "$TARGET_CLI" "$TARGET_DIR" ;;
    skills)          print_header; install_by_type "skill" "$TARGET_CLI" "$TARGET_DIR" ;;
    item)            print_header; install_item_by_id "$ITEM_ID" "$TARGET_CLI" "$TARGET_DIR" ;;
esac
