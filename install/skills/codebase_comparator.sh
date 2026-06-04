#!/usr/bin/env bash
# Run this script to generate codebase-comparator.zip

echo "📦 Creating codebase-comparator directory structure..."
mkdir -p codebase-comparator/scripts codebase-comparator/evals codebase-comparator/references

echo "📝 Writing SKILL.md..."
cat << 'EOF' > codebase-comparator/SKILL.md
---
name: codebase-comparator
description: A strict codebase comparison, feature reconciliation, and regression detection protocol. Use this skill when safely merging, auditing, or upgrading scripts by comparing a previous version against a proposed revision. It enforces an interactive feature-to-function matrix, mandates explicit user approval for every logic modification, and outputs final code in verified 500-line segments backed by the Superset Verification Protocol.
---

# Codebase Comparator & Regression Assessor

You are an unyielding, meticulous code integration agent operating natively in a text-based chat environment. Your primary objective is to prevent logic loss and code regression by forcing a strict, user-approved feature-by-feature reconciliation between two codebases, finalized through cryptographic segment verification.

Do NOT omit any logic from the baseline unless explicitly authorized by the user.

## Phase 1: Initialization & Input Collection
If the user has not provided the necessary context, halt and explicitly request the following:
1. **Codebase A** (Baseline / Previous)
2. **Codebase B** (Candidate / Proposed)
3. **Language/Framework** (To ensure accurate and idiomatic analysis)
4. **Shared Goal (Optional)** (e.g., "Merge the fast-path logic with the new UI.")

## Phase 2: Feature Matrix Generation
Analyze both codebases. Deconstruct the logic and output a comprehensive Feature Matrix using a Markdown table. You must classify the origin of every feature strictly as **Unique to A**, **Unique to B**, or **Common**.

*Format:*
| Feature Name | Description | Source | Status |
|--------------|-------------|--------|--------|
| [Name] | [Brief logic description] | `Unique to A` | Pending |
| [Name] | [Brief logic description] | `Common` | Pending |

## Phase 3: Interactive Decision Loop
Iterate through the pending features in the matrix. You must seek explicit approval for every single item. Do not assume the user's intent. 

Present the features in manageable batches (3-5 at a time) and ask the user to assign a decision to each using the following text-based commands:
* `[I] Include`: Mark for inclusion in the final codebase.
* `[R] Remove`: Mark for removal/omission.
* `[D] Discuss`: Halt the batch and discuss the specific feature's implications before deciding.

## Phase 4: Discussion & Resolution
If the user selects `[D] Discuss` for any feature, enter a sub-loop for that feature. 
1. Explain the root logic, security vectors, and idiomatic conventions of the feature.
2. Ask the user questions to narrow down their intent.
3. Do not proceed to Phase 5 until every `[D]` has been resolved into an `[I]` or `[R]`.

## Phase 5: Synthesis & Superset Verification Protocol
Once all features are strictly marked as `Include` or `Remove`, synthesize the final working script. This phase operates under strict zero-regression constraints.

**Output Rules:**
1. Generate the integrated code exactly as approved. **Zero unauthorized logic omission is tolerated.**
2. Output the code verbatim for direct copy/paste. No placeholders.
3. **Superset Constraint:** To bypass platform length constraints and prevent corruption, output the final code in strict segments of **no more than 500 lines per segment**. 
4. **Manifest Mandate:** Upon outputting the final segment, you must explicitly instruct the user to run their `superset_check.py` (or equivalent manifest generator) over the newly synthesized file to generate the SHA-256 segment hashes and verify zero regression against the baseline manifest.

## Phase 6: Post-Review Actions
After outputting the code and verification instructions, provide the user with a menu of post-review actions they can trigger by replying with a number:
* `[1] Generate Commit Message`: Draft a conventional commit summarizing the included/removed features.
* `[2] Show Diff`: Generate a text-based diff summary comparing the final synthesis to Codebase A.
* `[3] Analyze Root Cause`: If debugging, analyze the architectural flaw that necessitated the changes.
* `[4] Start Debugger/Follow-up`: Open a standard chat loop to manually tweak the generated segments.
EOF

echo "📝 Writing scripts/superset_check.py..."
cat << 'EOF' > codebase-comparator/scripts/superset_check.py
#!/usr/bin/env python3
"""
Superset Verification Protocol: Full Implementation
Strict segment/function hashing and manifest-based regression detection.
Author: 4ndr0666
License: MIT/WTFPL/Forcible Assimilation
"""

import hashlib, json, sys, os, argparse
import difflib
from collections import OrderedDict

SEGMENT_SIZE = 500  # lines per segment (customize as needed)

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha256_text(text):
    return sha256_bytes(text.encode('utf-8'))

def segment_file(file_path, segment_size=SEGMENT_SIZE):
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    segments = []
    for i in range(0, len(lines), segment_size):
        segment = ''.join(lines[i:i+segment_size])
        segments.append({
            'start': i+1,
            'end': min(i+segment_size, len(lines)),
            'content': segment,
            'sha256': sha256_text(segment)
        })
    return segments, lines

def compute_manifest(file_path, version_tag=None):
    segments, lines = segment_file(file_path)
    manifest = {
        "version": version_tag or os.path.basename(file_path),
        "timestamp": __import__('datetime').datetime.utcnow().isoformat()+'Z',
        "overall_sha256": sha256_text(''.join(lines)),
        "segments": OrderedDict(),
        "file": os.path.abspath(file_path),
        "line_count": len(lines)
    }
    for seg in segments:
        key = f"{seg['start']}-{seg['end']}"
        manifest["segments"][key] = seg["sha256"]
    return manifest

def load_manifest(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f, object_pairs_hook=OrderedDict)

def save_manifest(manifest, out_path):
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)

def compare_manifests(baseline, candidate):
    report = []
    baseline_segs = baseline["segments"]
    candidate_segs = candidate["segments"]
    all_keys = set(baseline_segs.keys()) | set(candidate_segs.keys())
    for key in sorted(all_keys, key=lambda x: int(x.split('-')[0])):
        b_hash = baseline_segs.get(key)
        c_hash = candidate_segs.get(key)
        if not b_hash and c_hash:
            report.append((key, "NEW", c_hash))
        elif b_hash and not c_hash:
            report.append((key, "MISSING", b_hash))
        elif b_hash == c_hash:
            report.append((key, "UNCHANGED", b_hash))
        else:
            report.append((key, "CHANGED", f"{b_hash[:8]} -> {c_hash[:8]}"))
    return report

def superset_check(baseline_path, candidate_path, baseline_manifest=None, manifest_out=None, verbose=True):
    if not baseline_manifest:
        baseline_manifest = compute_manifest(baseline_path, version_tag="baseline")
        save_manifest(baseline_manifest, "baseline_manifest.json")
    else:
        baseline_manifest = load_manifest(baseline_manifest)
    candidate_manifest = compute_manifest(candidate_path, version_tag="candidate")
    if manifest_out:
        save_manifest(candidate_manifest, manifest_out)

    report = compare_manifests(baseline_manifest, candidate_manifest)
    fail = False
    for key, status, hash_val in report:
        if status == "MISSING":
            print(f"[!] Segment {key} is MISSING in candidate. (hash: {hash_val})")
            fail = True
        elif status == "CHANGED":
            print(f"[!] Segment {key} CHANGED. ({hash_val})")
            b_start, b_end = map(int, key.split('-'))
            with open(baseline_path, 'r', encoding='utf-8', errors='replace') as f:
                b_lines = f.readlines()[b_start-1:b_end]
            with open(candidate_path, 'r', encoding='utf-8', errors='replace') as f:
                c_lines = f.readlines()[b_start-1:b_end]
            diff = list(difflib.unified_diff(b_lines, c_lines, fromfile='baseline', tofile='candidate', lineterm=''))
            if verbose and diff:
                print('\n'.join(diff))
        elif status == "NEW":
            print(f"[+] Segment {key} is NEW in candidate.")
        elif status == "UNCHANGED":
            if verbose:
                print(f"[=] Segment {key} is unchanged.")
    if fail:
        print("\n[FAIL] SUPRSET CHECK FAILED: Regression or segment missing detected.")
        sys.exit(1)
    print("\n[PASS] Superset protocol check complete. No regression found.")

def create_snapshot_checkpoint(file_path, out_manifest):
    manifest = compute_manifest(file_path)
    save_manifest(manifest, out_manifest)
    print(f"Snapshot checkpoint saved to {out_manifest}")

def main():
    parser = argparse.ArgumentParser(description="Superset Verification Protocol: Strict Code Regression Detector")
    parser.add_argument('--baseline', help='Path to baseline (golden) code file')
    parser.add_argument('--candidate', help='Path to candidate (new) code file')
    parser.add_argument('--baseline-manifest', help='Path to existing baseline manifest (optional)', default=None)
    parser.add_argument('--manifest', help='Output manifest for candidate/snapshot')
    parser.add_argument('--snapshot', help='Snapshot mode: just create manifest for file', action='store_true')
    parser.add_argument('--quiet', help='Quiet mode (minimal output)', action='store_true')
    args = parser.parse_args()

    if args.snapshot:
        if not args.candidate or not args.manifest:
            print("Snapshot mode requires --candidate <file> and --manifest <manifest.json>")
            sys.exit(2)
        create_snapshot_checkpoint(args.candidate, args.manifest)
        return

    if not args.baseline or not args.candidate:
        print("Both --baseline and --candidate are required unless in snapshot mode.")
        sys.exit(2)

    superset_check(args.baseline, args.candidate, baseline_manifest=args.baseline_manifest, manifest_out=args.manifest, verbose=not args.quiet)

if __name__ == '__main__':
    main()
EOF

echo "📝 Writing evals/evals.json..."
cat << 'EOF' > codebase-comparator/evals/evals.json
{
  "skill_name": "codebase-comparator",
  "evals": [
    {
      "id": 1,
      "prompt": "Compare these two bash scripts. Codebase A is my old merge tool, Codebase B is the new one. My goal is to keep the fast-path logic from A but use the AR composite engine from B.",
      "expected_output": "The skill should output a Feature Matrix, ask for decisions using [I]/[R]/[D], and ultimately output the merged script in 500-line segments.",
      "files": [],
      "expectations": [
        "The output includes a Markdown table classifying features as 'Unique to A', 'Unique to B', or 'Common'.",
        "The assistant explicitly halts to wait for user decisions ([I], [R], [D]) before generating code.",
        "The final code is presented in segments of 500 lines or fewer.",
        "The assistant instructs the user to run superset_check.py on the final output."
      ]
    },
    {
      "id": 2,
      "prompt": "I have two python files for a web scraper. Please compare them.",
      "expected_output": "The skill should generate the matrix and wait for user input.",
      "files": [],
      "expectations": [
        "The assistant generates the Feature Matrix.",
        "The assistant halts and prompts the user for [I], [R], or [D] decisions."
      ]
    }
  ]
}
EOF

echo "📝 Writing references/interactive_ux_mapping.md..."
cat << 'EOF' > codebase-comparator/references/interactive_ux_mapping.md
# Interactive UX Mapping Reference

This document maps the intended graphical user interface states into text-based chat states for the `codebase-comparator` skill.

## 1. Feature Matrix (FeatureMatrix.tsx)
The UI presents features in an accordion list with specific source chips and decision buttons.
* **Visual Source Chips** -> Translated to Matrix Columns: `Unique to A`, `Unique to B`, `Common`.
* **Decision Buttons (Include, Remove, Discuss)** -> Translated to text commands: 
    * `[I]` (Include: Marked for Inclusion)
    * `[R]` (Remove: Marked for Removal)
    * `[D]` (Discuss: Triggers sub-loop explanation)

## 2. Review Output & Actions (ReviewOutput.tsx)
The UI presents the generated code alongside post-review action buttons.
* **Generate Commit** -> Triggered via `[1]`.
* **Show Diff** -> Triggered via `[2]`.
* **Analyze Root Cause** -> Triggered via `[3]`.
* **Debugger / Follow-up** -> Triggered via `[4]`.

**Constraint Check:** The UI strictly disables the "Finalize Revision" button until ALL features have a decision. The LLM must enforce this same constraint conversationally by refusing to output the final script until every feature in the matrix has been assigned `[I]` or `[R]`.
EOF

echo "🗜️ Zipping files into codebase-comparator.zip..."
if command -v zip >/dev/null 2>&1; then
    zip -r codebase-comparator.zip codebase-comparator/
    echo "✅ Success! codebase-comparator.zip has been generated."
else
    echo "⚠️ 'zip' command not found. The files have been created in the 'codebase-comparator' directory."
    echo "You can manually compress this folder into a .zip file."
fi
