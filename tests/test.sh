#!/bin/bash
# End-to-end test of the fz-Serpent wrapper, as a user would run it:
# install -> fz list --check -> fzi -> fzc -> runner -> fzo -> fzr (no --calculators).
# Uses the real Serpent if SERPENT_BIN/sss2 is available and FZ_SERPENT_MOCK=0,
# otherwise the mock in tests/mock (CI has no Serpent licence).
# Usage: bash tests/test.sh   (from anywhere; needs fz >= 1.2 and python3)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
if [ "${FZ_SERPENT_MOCK:-1}" != "0" ]; then
  export PATH="$repo/tests/mock:$PATH"
  unset SERPENT_BIN
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() { echo "FAIL: $*" >&2; exit 1; }
# fz 1.2 prints warnings on stdout before the JSON document: keep the JSON only
jsononly() { sed -n '/^[[{]/,$p'; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo "== install from a local zip"
(cd "$repo" && python3 -c "
import zipfile, pathlib, sys
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    for p in pathlib.Path('.fz').rglob('*'):
        z.write(p, 'fz-Serpent-main/' + str(p))
" "$work/fz-Serpent.zip")
fz install model ./fz-Serpent.zip
[ -f .fz/models/Serpent.json ] || fail "model not installed"
[ -x .fz/calculators/Serpent.sh ] || fail "runner not installed/executable"

echo "== fz list --check"
fz list --check --format json | jsononly > list.json
python3 - <<'EOF' || fail "fz list --check"
import json
d = json.load(open("list.json"))
assert d["models"]["Serpent"]["check_status"] == "passed", d["models"]
# fz > 1.2 lists the alias by name; fz 1.2 lists it by URI and fails its check
# ("Empty sh:// command") although runs work: the fzr step below covers discovery.
calc = d["calculators"].get("localhost_Serpent")
assert calc is None or calc["check_status"] == "passed", d["calculators"]
EOF

input="$repo/examples/Serpent/input.inp"

echo "== fzi"
vars=$(fzi "$input" --model Serpent --format json | jsononly)
[ "$(echo "$vars" | json "d['enrichment']")" = "0.04" ] || fail "fzi default of enrichment"

echo "== fzc"
fzc -i "$input" --model Serpent -v '{"enrichment": 0.03}' --output_dir compiled > /dev/null
grep -q '^92235.09c -0.03$' compiled/*/input.inp || fail "enrichment not substituted"
grep -q '^92238.09c -0.8515$' compiled/*/input.inp || fail "U-238 formula not evaluated"
grep -q '[$]{' compiled/*/input.inp && fail "unsubstituted variable left"

echo "== runner in the case directory"
(cd compiled/*/ && bash "$work/.fz/calculators/Serpent.sh" input.inp) || fail "runner"
[ -s compiled/*/input.inp_res.m ] || fail "no _res.m"

echo "== runner failure modes (non-zero exit so that fz marks the case failed)"
runner="$work/.fz/calculators/Serpent.sh"
mkdir -p fails && cp compiled/*/input.inp fails/ && cd fails
SERPENT_BIN=false bash "$runner" input.inp > /dev/null 2>&1 && fail "Serpent error not reported"
printf '#!/bin/bash\nexit 0\n' > noresult && chmod +x noresult
SERPENT_BIN=./noresult bash "$runner" input.inp > /dev/null 2>&1 && fail "missing _res.m not reported"
SERPENT_BIN=/nonexistent/sss2 bash "$runner" input.inp > /dev/null 2>&1 && fail "missing executable not reported"
printf '#!/bin/bash\necho "$@" > args\ntouch "${@: -1}_res.m"; echo x > "${@: -1}_res.m"\n' > argcheck && chmod +x argcheck
SERPENT_BIN=./argcheck SERPENT_OMP=4 SERPENT_ARGS="-noplot" bash "$runner" input.inp > /dev/null \
  || fail "runner with options"
[ "$(cat args)" = "-omp 4 -noplot input.inp" ] || fail "options not passed: $(cat args)"
cd "$work"

echo "== fzo"
fzo 'compiled/*' --model Serpent --format json | jsononly > fzo.json
python3 - <<'EOF' || fail "fzo"
import json
r = json.load(open("fzo.json"))
r = r[0] if isinstance(r, list) else {k: list(v.values())[0] for k, v in r.items()}
assert isinstance(r["absKeff"], float) and 0.5 < r["absKeff"] < 2, r
assert isinstance(r["absKeff_err"], float) and 0 < r["absKeff_err"] < 1, r
assert r["burnup"] is None, r
EOF

echo "== fzo on a depletion result (one value per burnup step)"
mkdir -p depl && cp "$repo/tests/data/depletion_res.m" depl/input.inp_res.m
fzo depl --model Serpent --format json | jsononly > depl.json
python3 - <<'EOF' || fail "fzo depletion"
import json
r = json.load(open("depl.json"))
r = r[0] if isinstance(r, list) else {k: list(v.values())[0] for k, v in r.items()}
assert r["burnDays"] == [0.0, 25.0, 250.0], r
assert r["burnup"] == [0.0, 1.0, 10.0], r
assert r["absKeff"] == [1.30123, 1.27045, 1.19876], r
assert r["absKeff_err"] == [0.0008, 0.00082, 0.00085], r
EOF

echo "== fzr without --calculators (alias discovery)"
fzr "$input" --model Serpent -v '{"enrichment": [0.03, 0.05]}' --results_dir res \
    --format json | jsononly > fzr.json
python3 - <<'EOF' || fail "fzr"
import json
r = json.load(open("fzr.json"))
rows = r if isinstance(r, list) else [dict(zip(r, v)) for v in zip(*[c.values() for c in r.values()])]
assert len(rows) == 2, rows
assert all(row["status"] == "done" for row in rows), rows
k = {row["enrichment"]: row["absKeff"] for row in rows}
assert k[0.05] > k[0.03], k   # more U-235, higher k-eff
EOF

echo "All fz-Serpent tests passed"
