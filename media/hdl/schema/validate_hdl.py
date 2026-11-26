#!/usr/bin/env python3
"""4ndr0prompts HDL v8 structural and supplemental semantic validator.

Dependencies: pip install jsonschema>=4.18
Usage: python validate_hdl_v8.py prompt.json [more.json ...]
       python validate_hdl_v8.py --legacy prompt_arc-output.json
"""
import argparse
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator

HERE = Path(__file__).resolve().parent

class DuplicateJSONKey(ValueError):
    pass


def unique_object_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKey(f"duplicate JSON object key: {key!r}")
        result[key] = value
    return result


def semantic_errors(doc):
    """Invariants beyond JSON Schema 2020-12 expressiveness; no catalog guessing."""
    errors = []
    env = doc.get('!INIT_ATMOSPHERICS', {})
    if not isinstance(env, dict):
        return errors
    photo = env.get('!ENV_PHOTOMETRY', {})
    fin = env.get('!FINALIZE_OUTPUT', {})
    if isinstance(photo, dict) and isinstance(fin, dict):
        p_focus, f_focus = photo.get('FOCUS_LOCK'), fin.get('FOCUS_LOCK')
        if p_focus and f_focus and p_focus != f_focus:
            errors.append('focus conflict: !ENV_PHOTOMETRY.FOCUS_LOCK != !FINALIZE_OUTPUT.FOCUS_LOCK')
    mem = doc.get('!INIT_MEM_LOCK', {})
    material = env.get('!EXEC_MATERIAL_PHYSICS', {})
    if isinstance(mem, dict) and isinstance(material, dict):
        if mem.get('WARDROBE_LOCK') and material.get('WARDROBE_SPECIFICATION') and mem['WARDROBE_LOCK'] != material['WARDROBE_SPECIFICATION']:
            errors.append('wardrobe conflict: !INIT_MEM_LOCK.WARDROBE_LOCK != !EXEC_MATERIAL_PHYSICS.WARDROBE_SPECIFICATION')
    matrix = env.get('!EXEC_COMPOSITION_MATRIX', {})
    if isinstance(matrix, dict):
        declared = {f'PANEL_{i}' for i in range(1, 10) if f'PANEL_{i}' in matrix}
        for key in ('PANEL_KINEMATIC_LAYERS', 'PANEL_LIGHTING_OVERRIDES'):
            seen = set()
            for item in matrix.get(key, []) if isinstance(matrix.get(key, []), list) else []:
                if not isinstance(item, dict):
                    continue
                panel = item.get('PANEL')
                if panel not in declared:
                    errors.append(f'{key}: {panel!r} has no corresponding PANEL_n definition')
                if panel in seen:
                    errors.append(f'{key}: repeated panel mapping {panel!r}')
                seen.add(panel)
    return errors


def check(path, schema, legacy=False):
    try:
        doc = json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=unique_object_pairs)
    except (OSError, UnicodeError, json.JSONDecodeError, DuplicateJSONKey) as exc:
        return [f'JSON input error: {exc}']
    violations = []
    validator = Draft202012Validator(schema)
    for err in sorted(validator.iter_errors(doc), key=lambda x: (list(map(str, x.absolute_path)), x.message)):
        pointer = '/' + '/'.join(str(x).replace('~', '~0').replace('/', '~1') for x in err.absolute_path)
        violations.append(f'{pointer}: {err.message}')
    if not legacy and not violations:
        violations.extend(semantic_errors(doc))
    return violations


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--legacy', action='store_true', help='validate raw prompt_arc.py output with compatibility-only profile')
    parser.add_argument('--schema', type=Path, help='explicit JSON Schema path; overrides --legacy schema selection')
    parser.add_argument('documents', nargs='+', type=Path)
    options = parser.parse_args(argv)
    spath = options.schema or (HERE / ('hdl-v8.prompt-arc-legacy.schema.json' if options.legacy else 'hdl-v8.schema.json'))
    try:
        schema = json.loads(spath.read_text(encoding='utf-8'))
        Draft202012Validator.check_schema(schema)
    except Exception as exc:
        print(f'SCHEMA ERROR: {exc}', file=sys.stderr)
        return 2
    failed = 0
    for filename in options.documents:
        issues = check(filename, schema, legacy=options.legacy)
        if issues:
            failed += 1
            print(f'FAIL {filename}: {len(issues)} issue(s)')
            for issue in issues[:25]:
                print(f'  - {issue}')
            if len(issues) > 25:
                print(f'  ... {len(issues)-25} more issues')
        else:
            print(f'PASS {filename}')
    return 1 if failed else 0

if __name__ == '__main__':
    raise SystemExit(main())
