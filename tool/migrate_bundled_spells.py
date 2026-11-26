#!/usr/bin/env python3
"""Migrate bundled SpellItem catalogs to unified Spell.

Idempotent generator for Cleanup slice 17 (Fix 6.1):
- Converts all 10 static spell catalog files under lib/models/spells/ from
  SpellItem(...) to unified Spell(...) with EntityId, school + schoolEnum,
  CastingTime, SpellDuration, range, SpellComponents, descriptionMarkdown,
  higherLevelsMarkdown, rules2014, rules2024, and comparison metadata.
- Updates lib/models/spells/high_level_spells.dart to List<Spell>.
- Running a second time produces byte-identical files.
"""

from __future__ import annotations

import glob
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPELLS_DIR = ROOT / "lib" / "models" / "spells"


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


def parse_edition_details(rules_expr: str) -> dict[str, str]:
    open_p = rules_expr.index("(")
    close_p = find_matching_paren(rules_expr, open_p)
    return dict(split_top_level_args(rules_expr[open_p + 1 : close_p]))


def build_casting_time_expr(ct_str: str) -> str:
    low = ct_str.lower()
    if "bonus" in low:
        return "CastingTime(cost: 1, actionType: ActionType.bonusAction)"
    if "reaction" in low:
        return "CastingTime(cost: 1, actionType: ActionType.reaction)"
    return "CastingTime(cost: 1, actionType: ActionType.action)"


def build_duration_expr(dur_str: str, conc: bool) -> str:
    low = dur_str.lower()
    conc_str = "true" if conc else "false"
    if "instantaneous" in low:
        dt = "DurationType.instantaneous"
        secs = 0
    elif "permanent" in low or "until dispelled" in low:
        dt = "DurationType.permanent"
        secs = 0
    elif "special" in low:
        dt = "DurationType.special"
        secs = 0
    else:
        dt = "DurationType.timed"
        m = re.search(r"(\d+)\s*(round|minute|hour|day)", low)
        if m:
            val = int(m.group(1))
            unit = m.group(2)
            mult = {"round": 6, "minute": 60, "hour": 3600, "day": 86400}[unit]
            secs = val * mult
        else:
            secs = 0
    return (
        f"SpellDuration(type: {dt}, durationSeconds: {secs}, "
        f"requiresConcentration: {conc_str}, rawText: {dart_quote(dur_str)})"
    )


def build_components_expr(comp_str: str) -> str:
    v = "true" if re.search(r"\bV\b", comp_str) else "false"
    s = "true" if re.search(r"\bS\b", comp_str) else "false"
    m_flag = "true" if re.search(r"\bM\b", comp_str) else "false"
    mat_m = re.search(r"M\s*\((.+)\)", comp_str)
    if mat_m:
        mat_desc = f", materialDescription: {dart_quote(mat_m.group(1).strip())}"
    else:
        mat_desc = ""
    return f"SpellComponents(v: {v}, s: {s}, m: {m_flag}{mat_desc})"


def migrate_file(path: Path) -> tuple[str, int]:
    text = path.read_text(encoding="utf-8")
    if path.name == "high_level_spells.dart":
        return text.replace("List<SpellItem>", "List<Spell>"), 0

    out_parts: list[str] = []
    i = 0
    count = 0
    pattern = re.compile(r"\b(SpellItem|Spell)\(")
    while True:
        m = pattern.search(text, i)
        if not m:
            out_parts.append(text[i:].replace("List<SpellItem>", "List<Spell>"))
            break
        # Avoid matching SpellEditionDetails(, SpellComponents(, SpellDuration(, etc.
        if m.start() > 0 and (text[m.start() - 1].isalnum() or text[m.start() - 1] == "_"):
            out_parts.append(text[i : m.end()].replace("List<SpellItem>", "List<Spell>"))
            i = m.end()
            continue
        out_parts.append(text[i : m.start()].replace("List<SpellItem>", "List<Spell>"))
        open_idx = m.end() - 1
        close_idx = find_matching_paren(text, open_idx)
        body = text[open_idx + 1 : close_idx]
        args = split_top_level_args(body)
        arg_map = dict(args)
        count += 1

        id_expr = arg_map["id"]
        if id_expr.startswith("EntityId"):
            slug_m = re.search(r"slug:\s*('(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\")", id_expr)
            assert slug_m, f"Cannot parse EntityId slug in {id_expr}"
            slug = eval_dart_string(slug_m.group(1))
        else:
            slug = eval_dart_string(id_expr)

        if "schoolEnum" in arg_map:
            school_name = arg_map["schoolEnum"].split(".")[-1].strip()
        else:
            school_name = arg_map["school"].split(".")[-1].strip()

        r24_map = parse_edition_details(arg_map["rules2024"])
        ct_str = eval_dart_string(r24_map["castingTime"])
        range_str = eval_dart_string(r24_map["range"])
        comp_str = eval_dart_string(r24_map["components"])
        dur_str = eval_dart_string(r24_map["duration"])
        conc = r24_map.get("concentration", "false").strip() == "true"
        desc_list = eval_string_list(r24_map["description"])
        desc_md = "\n\n".join(desc_list)
        higher_expr = r24_map.get("higherLevels")

        lines_out = [
            f"    id: EntityId(slug: {dart_quote(slug)}, ruleset: RulesetVersion.v2024), name: {arg_map['name']},",
        ]
        if "name2014" in arg_map or "name2024" in arg_map:
            parts = [f"{k}: {arg_map[k]}" for k in ("name2014", "name2024") if k in arg_map]
            lines_out.append("    " + ", ".join(parts) + ",")
        lines_out.append(
            f"    level: {arg_map['level']}, school: {dart_quote(school_name)}, schoolEnum: SpellSchool.{school_name},"
        )
        lines_out.append(
            f"    castingTime: {build_casting_time_expr(ct_str)}, "
            f"duration: {build_duration_expr(dur_str, conc)},"
        )
        lines_out.append(
            f"    range: {dart_quote(range_str)}, components: {build_components_expr(comp_str)},"
        )
        hl_part = f", higherLevelsMarkdown: {higher_expr}" if higher_expr else ""
        lines_out.append(f"    descriptionMarkdown: {dart_quote(desc_md)}{hl_part},")
        meta_parts = [
            f"{k}: {arg_map[k]}"
            for k in ("isChangedIn2024", "diffSummary", "diffHighlights", "tags")
            if k in arg_map
        ]
        if meta_parts:
            lines_out.append("    " + ", ".join(meta_parts) + ",")
        lines_out.append(f"    rules2014: {arg_map['rules2014']},")
        lines_out.append(f"    rules2024: {arg_map['rules2024']},")

        rendered = "Spell(\n" + "\n".join(lines_out) + "\n  )"
        out_parts.append(rendered)
        i = close_idx + 1

    return "".join(out_parts), count


def main() -> int:
    total = 0
    files = sorted(Path(p) for p in glob.glob(str(SPELLS_DIR / "*.dart")))
    for f in files:
        new_text, cnt = migrate_file(f)
        f.write_text(new_text, encoding="utf-8")
        total += cnt
        print(f"migrated {f.relative_to(ROOT)}: {cnt} spells")
    print(f"TOTAL migrated static spells: {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
