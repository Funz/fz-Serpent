#!/usr/bin/env python3
"""
Structure and parsing tests for the fz-Serpent plugin (no Serpent needed).

Run with `pytest tests/` or `python tests/test_plugin.py`. The end-to-end run
(install, fzi, fzc, runner, fzo, fzr) is in tests/test.sh.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MODEL = REPO / ".fz" / "models" / "Serpent.json"
CALCULATOR = REPO / ".fz" / "calculators" / "localhost_Serpent.json"
RUNNER = REPO / ".fz" / "calculators" / "Serpent.sh"
EXAMPLE_INPUT = REPO / "examples" / "Serpent" / "input.inp"
EXAMPLE_RES = REPO / "examples" / "Serpent" / "input_res.m"
DEPLETION_RES = REPO / "tests" / "data" / "depletion_res.m"

OUTPUTS = ["absKeff", "anaKeff", "impKeff", "colKeff", "absKinf", "betaEff"]


def load_model():
    with open(MODEL) as f:
        return json.load(f)


def parse(res_file):
    """Run fz.fzo with the Serpent model on a case dir holding res_file."""
    import fz

    with tempfile.TemporaryDirectory() as tmp:
        case = Path(tmp) / "case"
        case.mkdir()
        shutil.copy(res_file, case / "input.inp_res.m")
        df = fz.fzo(str(case), load_model())
    return df.iloc[0].to_dict()


def test_model_file():
    model = load_model()
    assert model["id"] == "Serpent"
    assert model["commentline"] == "%"  # Serpent comment character
    assert model["delim"] == "{}"
    for name in OUTPUTS:
        assert name in model["output"] and name + "_err" in model["output"]
    assert "burnup" in model["output"] and "burnDays" in model["output"]


def test_calculator_files():
    with open(CALCULATOR) as f:
        calc = json.load(f)
    assert calc["uri"] == "sh://"
    assert calc["models"]["Serpent"] == "bash .fz/calculators/Serpent.sh"
    assert os.access(RUNNER, os.X_OK), "runner script not executable"
    subprocess.run(["bash", "-n", str(RUNNER)], check=True)


def test_fzi_finds_variables_with_defaults():
    import fz

    variables = fz.fzi(str(EXAMPLE_INPUT), load_model())
    assert variables["enrichment"] == 0.04
    for name in ["water_density", "fuel_radius", "neutrons_per_cycle", "seed"]:
        assert name in variables


def test_fzc_substitutes_variables_and_formula():
    import fz

    with tempfile.TemporaryDirectory() as tmp:
        fz.fzc(str(EXAMPLE_INPUT), {"enrichment": 0.03}, load_model(), output_dir=tmp)
        compiled = next(Path(tmp).rglob("input.inp")).read_text()
    assert "92235.09c -0.03\n" in compiled
    assert "92238.09c -0.8515\n" in compiled
    assert "${" not in compiled and "@{" not in compiled


def test_parse_criticality_result():
    r = parse(EXAMPLE_RES)
    assert r["absKeff"] == 1.15295 and r["absKeff_err"] == 0.00094
    assert r["anaKeff"] == 1.15583 and r["anaKeff_err"] == 0.00176
    assert r["impKeff"] == 1.15295 and r["colKeff"] == 1.15307
    assert r["absKinf"] == 1.15295
    assert r["betaEff"] == 0.0068797 and r["betaEff_err"] == 0.027
    assert r["cpuTime"] == 0.828167
    assert r["burnup"] is None and r["burnDays"] is None


def test_parse_depletion_result():
    r = parse(DEPLETION_RES)
    assert r["burnup"] == [0.0, 1.0, 10.0]
    assert r["burnDays"] == [0.0, 25.0, 250.0]
    assert r["absKeff"] == [1.30123, 1.27045, 1.19876]
    assert r["absKeff_err"] == [0.0008, 0.00082, 0.00085]


if __name__ == "__main__":
    tests = [(n, f) for n, f in sorted(globals().items()) if n.startswith("test_")]
    failed = 0
    for name, func in tests:
        try:
            func()
            print(f"✓ {name}")
        except Exception as e:  # report every failure, not just the first
            failed += 1
            print(f"✗ {name}: {e!r}")
    sys.exit(1 if failed else 0)
