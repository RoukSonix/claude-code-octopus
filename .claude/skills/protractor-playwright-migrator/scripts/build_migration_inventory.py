#!/usr/bin/env python3
"""Build a Protractor-to-Playwright migration inventory and mapping table."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path

IGNORE_DIRS = {'.git', 'node_modules', 'dist', 'build', 'out', 'coverage'}
CODE_EXTENSIONS = {'.ts', '.js'}
CATEGORY_ORDER = ['specs', 'pages', 'elements', 'data', 'utils', 'other']
UTILS_TOKEN_RE = re.compile(r'(^|[-_.])(util|utils|helper|helpers)([-_.]|$)')
ELEMENTS_TOKEN_RE = re.compile(r'(^|[-_.])(element|elements)([-_.]|$)')
PAGES_TOKEN_RE = re.compile(r'(^|[-_.])(page|list-page|form-page)([-_.]|$)')


@dataclass
class InventoryItem:
    source: str
    category: str
    target: str
    notes: list[str]


def is_ignored(path: Path) -> bool:
    return any(part in IGNORE_DIRS for part in path.parts)


def classify(relative_path: Path) -> str:
    parts = [part.lower() for part in relative_path.parts]
    directories = parts[:-1]
    name = relative_path.name.lower()

    # 1) Directory-based classification has highest priority.
    if 'specs' in directories:
        return 'specs'
    if 'pages' in directories:
        return 'pages'
    if 'elements' in directories:
        return 'elements'
    if 'data' in directories:
        return 'data'
    if 'utils' in directories:
        return 'utils'

    # 2) Filename-based fallback classification.
    if re.search(r'\.(spec|test)\.(ts|js)$', name):
        return 'specs'
    if ELEMENTS_TOKEN_RE.search(name):
        return 'elements'
    if name.endswith('.data.ts') or name.endswith('.data.js'):
        return 'data'
    if UTILS_TOKEN_RE.search(name):
        return 'utils'
    if PAGES_TOKEN_RE.search(name):
        return 'pages'
    return 'other'


def normalize_filename(filename: str, category: str) -> tuple[str, list[str]]:
    notes: list[str] = []
    lower_name = filename.lower()

    normalized = filename
    if lower_name.endswith('.js'):
        normalized = f'{filename[:-3]}.ts'
        notes.append('Convert JavaScript source to TypeScript.')

    if category == 'specs':
        if re.search(r'\.spec\.(ts|js)$', lower_name):
            normalized = re.sub(r'\.js$', '.ts', normalized)
        elif re.search(r'\.test\.(ts|js)$', lower_name):
            normalized = re.sub(r'\.test\.(ts|js)$', '.spec.ts', normalized)
            notes.append('Rename .test.* to .spec.ts to match repository convention.')
        elif normalized.endswith('.ts'):
            normalized = normalized[:-3] + '.spec.ts'
            notes.append('Ensure migrated spec file uses .spec.ts suffix.')

    if 'extjs' in lower_name:
        notes.append('Likely Classic UI (7.x) artifact; validate Base7xPage family mapping.')

    return normalized, notes


def nested_suffix(relative_path: Path, category: str) -> Path:
    parts = list(relative_path.parts)
    category_to_part = {
        'specs': 'specs',
        'pages': 'pages',
        'elements': 'elements',
        'data': 'data',
        'utils': 'utils',
    }
    expected_part = category_to_part.get(category)
    if not expected_part:
        return Path()

    lowered = [part.lower() for part in parts]
    if expected_part in lowered:
        index = lowered.index(expected_part)
        parent_parts = parts[index + 1 : -1]
        return Path(*parent_parts) if parent_parts else Path()

    return Path()


def propose_target(relative_path: Path, category: str, target_root: Path) -> tuple[Path, list[str]]:
    normalized_name, notes = normalize_filename(relative_path.name, category)
    nested_path = nested_suffix(relative_path, category)

    target_category = category if category in {'specs', 'pages', 'elements', 'data', 'utils', 'other'} else 'other'
    if category == 'other':
        notes.append('Category is ambiguous; manual placement review is required before implementation.')

    target = target_root / target_category
    if str(nested_path) != '.':
        target = target / nested_path
    target = target / normalized_name
    return target, notes


def collect_inventory(source_root: Path, target_root: Path) -> list[InventoryItem]:
    items: list[InventoryItem] = []

    for file_path in sorted(source_root.rglob('*')):
        if not file_path.is_file() or file_path.suffix.lower() not in CODE_EXTENSIONS:
            continue
        if is_ignored(file_path.relative_to(source_root)):
            continue

        relative_path = file_path.relative_to(source_root)
        category = classify(relative_path)
        target, notes = propose_target(relative_path, category, target_root)

        items.append(
            InventoryItem(
                source=str(relative_path),
                category=category,
                target=str(target),
                notes=notes,
            )
        )

    return items


def render_markdown(items: list[InventoryItem], source_root: Path, target_root: Path) -> str:
    counts = {category: 0 for category in CATEGORY_ORDER}
    for item in items:
        counts[item.category] += 1

    lines: list[str] = []
    lines.append('# Migration Inventory')
    lines.append('')
    lines.append(f'- Source: `{source_root}`')
    lines.append(f'- Target: `{target_root}`')
    lines.append(f'- Total code files: {len(items)}')
    lines.append('')
    lines.append('## Category Summary')
    lines.append('')
    for category in CATEGORY_ORDER:
        lines.append(f'- {category}: {counts[category]}')
    lines.append('')
    lines.append('## Proposed Mapping')
    lines.append('')
    lines.append('| Source | Category | Proposed Target | Notes |')
    lines.append('|---|---|---|---|')

    for item in items:
        notes = '; '.join(item.notes)
        lines.append(f'| `{item.source}` | `{item.category}` | `{item.target}` | {notes} |')

    lines.append('')
    lines.append('## Next Actions')
    lines.append('')
    lines.append('- Validate mapping for `other` category files manually.')
    lines.append('- Confirm target paths stay inside `tests/_migrated/features/<feature>/...`.')
    lines.append('- Use TestKit docs before applying migration edits.')
    return '\n'.join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Build migration inventory for Protractor to Playwright migration tasks.')
    parser.add_argument('--source', required=True, help='Protractor source directory.')
    parser.add_argument('--target', required=True, help='Playwright target directory.')
    parser.add_argument('--output', help='Optional file path to write report to. Prints to stdout if omitted.')
    parser.add_argument('--format', choices=['markdown', 'json'], default='markdown', help='Output format.')
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    source_root = Path(args.source).expanduser().resolve()
    target_root = Path(args.target).expanduser().resolve()

    if not source_root.exists() or not source_root.is_dir():
        raise SystemExit(f'Source directory does not exist or is not a directory: {source_root}')

    items = collect_inventory(source_root, target_root)

    if args.format == 'json':
        payload = {
            'source': str(source_root),
            'target': str(target_root),
            'total': len(items),
            'items': [asdict(item) for item in items],
        }
        output = json.dumps(payload, indent=2)
    else:
        output = render_markdown(items, source_root, target_root)

    if args.output:
        output_path = Path(args.output).expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output + '\n', encoding='utf-8')
    else:
        print(output)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
