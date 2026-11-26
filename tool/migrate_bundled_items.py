#!/usr/bin/env python3
"""Migrate bundled MagicItem catalogs to EquipmentItem + ItemPresentation registry.

Idempotent generator for Cleanup slice 17 (Fixes 5.1, 5.2):
- Extracts glyphColor/glyphArgb, damageAccent, and actionRings from the 10
  static item catalog files under lib/models/magic_items/items/ into
  lib/models/magic_items/item_presentation_registry.dart.
- Computes each item's rules customProperties (AC/weapon/spell bonuses, baseAc,
  armorType, maxDexBonus, isShield, shieldBonus, isWeapon, defaultSlot, cost,
  category, tags) once and writes them as static data into each EquipmentItem.
- Running a second time produces byte-identical files.
"""

from __future__ import annotations

import glob
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ITEMS_DIR = ROOT / "lib" / "models" / "magic_items" / "items"
REGISTRY_PATH = ROOT / "lib" / "models" / "magic_items" / "item_presentation_registry.dart"


def skip_ws_and_comments(s: str, i: int) -> int:
    n = len(s)
    while i < n:
        if s[i].isspace():
            i += 1
        elif s.startswith("//", i):
            nl = s.find("\n", i)
            i = n if nl == -1 else nl + 1
        elif s.startswith("/*", i):
            end = s.find("*/", i + 2)
            i = n if end == -1 else end + 2
        else:
            break
    return i


def read_string_literal(s: str, i: int) -> int:
    n = len(s)
    raw = False
    if s[i] == "r" and i + 1 < n and s[i + 1] in ("'", '"'):
        raw = True
        i += 1
    q = s[i]
    if s.startswith(q * 3, i):
        delim = q * 3
        i += 3
        while i < n:
            if not raw and s[i] == "\\":
                i += 2
                continue
            if s.startswith(delim, i):
                return i + 3
            i += 1
        return n
    i += 1
    while i < n:
        if not raw and s[i] == "\\":
            i += 2
            continue
        if s[i] == q:
            return i + 1
        i += 1
    return n


def find_matching_paren(s: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    n = len(s)
    while i < n:
        c = s[i]
        if s.startswith("//", i):
            nl = s.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if s.startswith("/*", i):
            end = s.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        if c in ("'", '"') or (c == "r" and i + 1 < n and s[i + 1] in ("'", '"')):
            i = read_string_literal(s, i)
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"Unmatched paren at {open_idx}")


def split_top_level_args(body: str) -> list[tuple[str, str]]:
    """Parse named arguments `name: expr` from a constructor argument list."""
    args: list[tuple[str, str]] = []
    i = 0
    n = len(body)
    while True:
        i = skip_ws_and_comments(body, i)
        if i >= n:
            break
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", body[i:])
        if not m:
            raise ValueError(f"Expected named arg near: {body[i:i+60]!r}")
        name = m.group(1)
        val_start = skip_ws_and_comments(body, i + m.end())
        j = val_start
        depth = 0
        while j < n:
            c = body[j]
            if body.startswith("//", j):
                nl = body.find("\n", j)
                j = n if nl == -1 else nl + 1
                continue
            if body.startswith("/*", j):
                end = body.find("*/", j + 2)
                j = n if end == -1 else end + 2
                continue
            if c in ("'", '"') or (c == "r" and j + 1 < n and body[j + 1] in ("'", '"')):
                j = read_string_literal(body, j)
                continue
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            elif c == "," and depth == 0:
                break
            j += 1
        val = body[val_start:j].strip()
        args.append((name, val))
        i = j + 1 if j < n and body[j] == "," else j
    return args


def eval_dart_string(expr: str) -> str:
    """Evaluate a Dart string literal (including adjacent concatenated literals)."""
    out: list[str] = []
    i = 0
    n = len(expr)
    while i < n:
        i = skip_ws_and_comments(expr, i)
        if i >= n:
            break
        raw = False
        if expr[i] == "r" and i + 1 < n and expr[i + 1] in ("'", '"'):
            raw = True
            i += 1
        if expr[i] not in ("'", '"'):
            raise ValueError(f"Expected string literal in {expr!r} at {i}")
        q = expr[i]
        if expr.startswith(q * 3, i):
            end = read_string_literal(expr, i - (1 if raw else 0))
            inner = expr[i + 3 : end - 3]
        else:
            end = read_string_literal(expr, i - (1 if raw else 0))
            inner = expr[i + 1 : end - 1]
        if raw:
            out.append(inner)
        else:
            # Unescape common Dart escapes
            inner = (
                inner.replace(r"\\", "\x00BS\x00")
                .replace(r"\'", "'")
                .replace(r'\"', '"')
                .replace(r"\n", "\n")
                .replace(r"\r", "\r")
                .replace(r"\t", "\t")
                .replace(r"\$", "$")
                .replace("\x00BS\x00", "\\")
            )
            out.append(inner)
        i = end
    return "".join(out)


def dart_quote(s: str) -> str:
    escaped = (
        s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f"'{escaped}'"


def eval_string_list(expr: str) -> list[str]:
    inner = expr.strip()
    if inner.startswith("const"):
        inner = inner[5:].strip()
    if inner.startswith("<String>"):
        inner = inner[8:].strip()
    assert inner.startswith("[") and inner.endswith("]"), f"Not a list: {expr!r}"
    body = inner[1:-1]
    items: list[str] = []
    i = 0
    n = len(body)
    while i < n:
        i = skip_ws_and_comments(body, i)
        if i >= n:
            break
        start = i
        while i < n:
            c = body[i]
            if c in ("'", '"') or (c == "r" and i + 1 < n and body[i + 1] in ("'", '"')):
                i = read_string_literal(body, i)
                continue
            if c == ",":
                break
            i += 1
        chunk = body[start:i].strip()
        if chunk:
            items.append(eval_dart_string(chunk))
        if i < n and body[i] == ",":
            i += 1
    return items


def extract_summary(rules_expr: str) -> str:
    open_p = rules_expr.index("(")
    close_p = find_matching_paren(rules_expr, open_p)
    for k, v in split_top_level_args(rules_expr[open_p + 1 : close_p]):
        if k == "summary":
            return eval_dart_string(v)
    return ""


def compute_custom_properties(
    name: str,
    category: str,
    tags: list[str],
    cost: str | None,
    cost2024: str | None,
    cost2014: str | None,
) -> list[tuple[str, str]]:
    """Exact port of SrdEquipmentLibrary._mapItemToEquipmentItem rules extraction."""
    effective_cost = cost if cost is not None else (cost2024 if cost2024 is not None else cost2014)
    props: dict[str, str] = {
        "cost": "null" if effective_cost is None else dart_quote(effective_cost),
        "category": dart_quote(category),
        "tags": "[" + ", ".join(dart_quote(t) for t in tags) + "]",
    }

    pact_m = re.search(r"rod\s+of\s+the\s+pact\s+keeper(?:,\s*|\s*)\+(\d+)", name, re.I)
    if pact_m:
        b = int(pact_m.group(1))
        props["bonusSpellAttack"] = str(b)
        props["bonusSpellSaveDc"] = str(b)
        props["spellDcBonus"] = str(b)
        props["spellClass"] = "'warlock'"

    war_m = re.search(r"wand\s+of\s+the\s+war\s+mage(?:,\s*|\s*)\+(\d+)", name, re.I)
    if war_m:
        b = int(war_m.group(1))
        props["bonusSpellAttack"] = str(b)

    ac_m = re.search(
        r"(?:armor|shield|plate|breastplate|chain|leather|hide|ring of protection|cloak of protection)(?:,\s*|\s*)\+(\d+)",
        name,
        re.I,
    )
    if ac_m is None and category == "armor":
        ac_m = re.search(r"\+(\d+)", name)
    if ac_m:
        b = int(ac_m.group(1))
        props["bonusAc"] = str(b)
        props["acBonus"] = str(b)
    elif name.lower() in ("ring of protection", "cloak of protection"):
        props["bonusAc"] = "1"
        props["acBonus"] = "1"

    is_shield = category == "armor" and ("shield" in name.lower() or "shield" in tags)
    if is_shield:
        props["isShield"] = "true"
        props["shieldBonus"] = "2"
        props["defaultSlot"] = "EquipmentSlot.shield"
    elif category == "armor" or "armor" in tags:
        props["defaultSlot"] = "EquipmentSlot.armor"
        nl = name.lower()
        if "breastplate" in nl:
            props["baseAc"] = "14"
            props["armorType"] = "'medium'"
            props["maxDexBonus"] = "2"
        elif "half plate" in nl:
            props["baseAc"] = "15"
            props["armorType"] = "'medium'"
            props["maxDexBonus"] = "2"
        elif "plate" in nl:
            props["baseAc"] = "18"
            props["armorType"] = "'heavy'"
            props["maxDexBonus"] = "0"
        elif "splint" in nl:
            props["baseAc"] = "17"
            props["armorType"] = "'heavy'"
            props["maxDexBonus"] = "0"
        elif "chain mail" in nl:
            props["baseAc"] = "16"
            props["armorType"] = "'heavy'"
            props["maxDexBonus"] = "0"
        elif "ring mail" in nl:
            props["baseAc"] = "14"
            props["armorType"] = "'heavy'"
            props["maxDexBonus"] = "0"
        elif "scale mail" in nl:
            props["baseAc"] = "14"
            props["armorType"] = "'medium'"
            props["maxDexBonus"] = "2"
        elif "chain shirt" in nl or "elven chain" in nl:
            props["baseAc"] = "13"
            props["armorType"] = "'medium'"
            props["maxDexBonus"] = "2"
        elif "hide" in nl:
            props["baseAc"] = "12"
            props["armorType"] = "'medium'"
            props["maxDexBonus"] = "2"
        elif "studded leather" in nl or "studded" in nl:
            props["baseAc"] = "12"
            props["armorType"] = "'light'"
        elif "leather" in nl or "padded" in nl:
            props["baseAc"] = "11"
            props["armorType"] = "'light'"

    w_m = re.search(
        r"(?:weapon|sword|bow|axe|dagger|mace|hammer|spear)(?:,\s*|\s*)\+(\d+)",
        name,
        re.I,
    )
    if w_m:
        b = int(w_m.group(1))
        props["attackBonus"] = str(b)
        props["magicBonus"] = str(b)
        props["bonusWeapon"] = str(b)

    if category == "weapon" or "weapon" in tags:
        props["isWeapon"] = "true"
        props["defaultSlot"] = "EquipmentSlot.mainHand"
    if category == "ring" or "ring" in tags:
        props["defaultSlot"] = "EquipmentSlot.ring1"

    return list(props.items())


def compact_expr(expr: str) -> str:
    """Collapse internal newlines/multi-spaces outside string literals for compact registry lines."""
    out: list[str] = []
    i = 0
    n = len(expr)
    in_space = False
    while i < n:
        c = expr[i]
        if c in ("'", '"') or (c == "r" and i + 1 < n and expr[i + 1] in ("'", '"')):
            if in_space:
                out.append(" ")
                in_space = False
            end = read_string_literal(expr, i)
            out.append(expr[i:end])
            i = end
            continue
        if expr.startswith("//", i):
            nl = expr.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if c.isspace():
            in_space = True
            i += 1
            continue
        if in_space:
            out.append(" ")
            in_space = False
        out.append(c)
        i += 1
    return "".join(out).strip()


def migrate_file(path: Path, presentations: dict[str, dict[str, str]]) -> tuple[str, int]:
    text = path.read_text(encoding="utf-8")
    out_parts: list[str] = []
    i = 0
    n = len(text)
    count = 0

    # Replace List<MagicItem> -> List<EquipmentItem>
    # We'll process constructor calls MagicItem(...) or EquipmentItem(...)
    pattern = re.compile(r"\b(MagicItem|EquipmentItem)\(")
    while True:
        m = pattern.search(text, i)
        if not m:
            out_parts.append(text[i:].replace("List<MagicItem>", "List<EquipmentItem>"))
            break
        prefix = text[i : m.start()].replace("List<MagicItem>", "List<EquipmentItem>")
        out_parts.append(prefix)
        open_idx = m.end() - 1
        close_idx = find_matching_paren(text, open_idx)
        body = text[open_idx + 1 : close_idx]
        args = split_top_level_args(body)
        arg_map = dict(args)
        count += 1

        # Determine slug
        id_expr = arg_map["id"]
        if id_expr.startswith("EntityId"):
            slug_m = re.search(r"slug:\s*('(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\")", id_expr)
            assert slug_m, f"Cannot parse EntityId slug in {id_expr}"
            slug = eval_dart_string(slug_m.group(1))
        else:
            slug = eval_dart_string(id_expr)

        name = eval_dart_string(arg_map["name"])
        cat_expr = arg_map["category"]
        cat_name = cat_expr.split(".")[-1].strip()
        if "rarityTier" in arg_map:
            rar_expr = arg_map["rarityTier"]
        else:
            rar_expr = arg_map["rarity"]
        rar_name = rar_expr.split(".")[-1].strip()

        cost = eval_dart_string(arg_map["cost"]) if "cost" in arg_map and arg_map["cost"] != "null" else None
        cost2014 = eval_dart_string(arg_map["cost2014"]) if "cost2014" in arg_map and arg_map["cost2014"] != "null" else None
        cost2024 = eval_dart_string(arg_map["cost2024"]) if "cost2024" in arg_map and arg_map["cost2024"] != "null" else None
        tags = eval_string_list(arg_map["tags"]) if "tags" in arg_map else []

        # Collect presentation fields if present (first run)
        pres: dict[str, str] = {}
        if "glyphColor" in arg_map:
            pres["glyphArgb"] = compact_expr(arg_map["glyphColor"])
        elif "glyphArgb" in arg_map:
            pres["glyphArgb"] = compact_expr(arg_map["glyphArgb"])
        if "damageAccent" in arg_map:
            pres["damageAccent"] = compact_expr(arg_map["damageAccent"])
        if "actionRings" in arg_map:
            pres["actionRings"] = compact_expr(arg_map["actionRings"])
        if pres:
            presentations[slug] = pres

        # Determine descriptionMarkdown
        if "descriptionMarkdown" in arg_map:
            desc_md_expr = arg_map["descriptionMarkdown"]
        else:
            s24 = extract_summary(arg_map["rules2024"]) if "rules2024" in arg_map else ""
            s14 = extract_summary(arg_map["rules2014"]) if "rules2014" in arg_map else ""
            desc_md_expr = dart_quote(s24 if s24 else s14)

        req_attune = arg_map.get("requiresAttunement", "false")
        custom_props = compute_custom_properties(name, cat_name, tags, cost, cost2024, cost2014)
        props_str = "{ " + ", ".join(f"{dart_quote(k)}: {v}" for k, v in custom_props) + " }"

        # Build unified EquipmentItem constructor call (compact so big-file ceilings never grow)
        lines_out = [
            f"      id: EntityId(slug: {dart_quote(slug)}, ruleset: RulesetVersion.v2024), name: {arg_map['name']},",
        ]
        if "name2014" in arg_map or "name2024" in arg_map:
            parts = [f"{k}: {arg_map[k]}" for k in ("name2014", "name2024") if k in arg_map]
            lines_out.append("      " + ", ".join(parts) + ",")
        lines_out.append(
            f"      itemType: {dart_quote(cat_name)}, category: ItemCategory.{cat_name}, "
            f"rarity: {dart_quote(rar_name)}, rarityTier: ItemRarity.{rar_name},"
        )
        if any(k in arg_map for k in ("cost", "cost2014", "cost2024")):
            parts = [f"{k}: {arg_map[k]}" for k in ("cost", "cost2014", "cost2024") if k in arg_map]
            lines_out.append("      " + ", ".join(parts) + ",")
        att_part = f", attunementRequirement: {arg_map['attunementRequirement']}" if "attunementRequirement" in arg_map else ""
        lines_out.append(f"      requiresAttunement: {req_attune}{att_part},")
        lines_out.append(f"      descriptionMarkdown: {desc_md_expr},")
        for opt in ("rules2014", "rules2024"):
            if opt in arg_map:
                lines_out.append(f"      {opt}: {arg_map[opt]},")
        meta_parts = [f"{k}: {arg_map[k]}" for k in ("isChangedIn2024", "diffSummary", "diffHighlights", "tags", "grants") if k in arg_map]
        if meta_parts:
            lines_out.append("      " + ", ".join(meta_parts) + ",")
        lines_out.append(f"      customProperties: {props_str},")

        rendered = "EquipmentItem(\n" + "\n".join(lines_out) + "\n    )"
        out_parts.append(rendered)
        i = close_idx + 1

    return "".join(out_parts), count


def write_registry(presentations: dict[str, dict[str, str]]) -> None:
    lines = [
        "// GENERATED BY tool/migrate_bundled_items.py — DO NOT EDIT BY HAND.",
        "import '../visual/glyph_kinds.dart';",
        "",
        "/// Visual presentation metadata attached to bundled items by item slug.",
        "class ItemPresentation {",
        "  final Argb? glyphArgb;",
        "  final DamageAccent? damageAccent;",
        "  final List<ActionTraitRing> actionRings;",
        "",
        "  const ItemPresentation({",
        "    this.glyphArgb,",
        "    this.damageAccent,",
        "    this.actionRings = const [],",
        "  });",
        "}",
        "",
        "const Map<String, ItemPresentation> kBundledItemPresentation = {",
    ]
    for slug in sorted(presentations.keys()):
        p = presentations[slug]
        parts = []
        if "glyphArgb" in p:
            parts.append(f"glyphArgb: {p['glyphArgb']}")
        if "damageAccent" in p:
            parts.append(f"damageAccent: {p['damageAccent']}")
        if "actionRings" in p:
            parts.append(f"actionRings: {p['actionRings']}")
        lines.append(f"  {dart_quote(slug)}: ItemPresentation({', '.join(parts)}),")
    lines.append("};")
    lines.append("")
    REGISTRY_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    presentations: dict[str, dict[str, str]] = {}
    total = 0
    files = sorted(
        Path(p)
        for p in glob.glob(str(ITEMS_DIR / "*.dart"))
        if not p.endswith("srd_loot_items.dart")
    )
    for f in files:
        new_text, cnt = migrate_file(f, presentations)
        f.write_text(new_text, encoding="utf-8")
        total += cnt
        print(f"migrated {f.relative_to(ROOT)}: {cnt} items")
    if presentations:
        write_registry(presentations)
        print(f"wrote {REGISTRY_PATH.relative_to(ROOT)}: {len(presentations)} entries")
    else:
        print(f"kept existing {REGISTRY_PATH.relative_to(ROOT)} (already migrated)")
    print(f"TOTAL migrated static items: {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
