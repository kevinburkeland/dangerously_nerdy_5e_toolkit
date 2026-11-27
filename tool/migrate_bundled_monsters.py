#!/usr/bin/env python3
"""Idempotent generator for Cleanup slice 18 Step 6 (Fix 6.1).

Migrates the five bundled bestiary files under
`lib/models/monster_codex/bestiary/` from app `MonsterItem` to unified ruleset
`Monster`, wrapping string ids in `EntityId(slug: '...', ruleset: RulesetVersion.v2014)`
inside `const Monster.simple(...)` entries and removing the redundant
`minion_stat_block.dart` import.

Idempotent: running a second time produces byte-identical files.
"""

import glob
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BESTIARY_GLOB = "lib/models/monster_codex/bestiary/*.dart"

REDUNDANT_IMPORT_RE = re.compile(
    r"^import '\.\./\.\./srd_summons/minion_stat_block\.dart';\r?\n",
    re.MULTILINE,
)
LIST_TYPE_RE = re.compile(r"\bList<MonsterItem>")
SIMPLE_CTOR_RE = re.compile(
    r"(?<!const )MonsterItem\.simple\(\s*\n(\s*)id:\s*'([^']+)',",
    re.MULTILINE,
)
INNER_CONST_SB_RE = re.compile(r"statBlock:\s*const\s+MonsterStatBlock\(")


def migrate_file(path: Path) -> tuple[bool, dict[str, int]]:
    original = path.read_text(encoding="utf-8")
    updated = original

    updated, import_removals = REDUNDANT_IMPORT_RE.subn("", updated)
    updated, list_renames = LIST_TYPE_RE.subn("List<Monster>", updated)
    updated, simple_renames = SIMPLE_CTOR_RE.subn(
        r"const Monster.simple(\n\1id: EntityId(slug: '\2', ruleset: RulesetVersion.v2014),",
        updated,
    )
    updated, inner_const_cleanups = INNER_CONST_SB_RE.subn(
        "statBlock: MonsterStatBlock(",
        updated,
    )

    changed = updated != original
    if changed:
        path.write_text(updated, encoding="utf-8")
    return changed, {
        "import_removals": import_removals,
        "list_renames": list_renames,
        "simple_renames": simple_renames,
        "inner_const_cleanups": inner_const_cleanups,
    }


def main() -> int:
    files = sorted(Path(p) for p in glob.glob(str(ROOT / BESTIARY_GLOB)))
    changed_files = 0
    totals = {
        "import_removals": 0,
        "list_renames": 0,
        "simple_renames": 0,
        "inner_const_cleanups": 0,
    }
    for path in files:
        changed, counts = migrate_file(path)
        if changed:
            changed_files += 1
        for k, v in counts.items():
            totals[k] += v
    print(
        f"migrate_bundled_monsters: scanned={len(files)} "
        f"changed_files={changed_files} "
        f"import_removals={totals['import_removals']} "
        f"list_renames={totals['list_renames']} "
        f"simple_renames={totals['simple_renames']} "
        f"inner_const_cleanups={totals['inner_const_cleanups']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
