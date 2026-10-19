#!/usr/bin/env python3
"""
Basic test suite for fz-Serpent plugin.

These tests verify the plugin structure.
They test:
- Model file validity
- Variable parsing
- Input file compilation
- Calculator configuration
"""

import os
import json
import tempfile
import sys


def test_model_files():
    """Test that all model JSON files are valid and have required fields."""
    print("Testing model files...")
    
    models = [
        ".fz/models/Serpent.json"
    ]
    
    required_fields = ["id", "varprefix", "delim", "commentline", "output"]
    
    for model_file in models:
        print(f"  Checking {model_file}...", end=" ")
        
        # Check file exists
        assert os.path.exists(model_file), f"File not found: {model_file}"
        
        # Load and validate JSON
        with open(model_file, 'r') as f:
            model = json.load(f)
        
        # Check required fields
        for field in required_fields:
            assert field in model, f"Missing field '{field}' in {model_file}"
        
        # Check output section has at least one variable
        assert len(model["output"]) > 0, f"No output variables in {model_file}"
        
        # Verify model id matches expected
        assert model["id"] == "Serpent", f"Model id should be 'Serpent'"
        
        # Verify Serpent uses % for comments
        assert model["commentline"] == "%", f"Serpent uses % for comments"
        
        print("✓")
    
    print("  All model files valid!\n")


def test_calculator_files():
    """Test that calculator JSON files are valid."""
    print("Testing calculator configuration files...")

    calculators = [
        ".fz/calculators/localhost_Serpent.json"
    ]
    
    for calc_file in calculators:
        print(f"  Checking {calc_file}...", end=" ")
        
        # Check file exists
        assert os.path.exists(calc_file), f"File not found: {calc_file}"
        
        # Load and validate JSON
        with open(calc_file, 'r') as f:
            calc = json.load(f)
        
        # Check required fields
        assert "uri" in calc, f"Missing 'uri' field in {calc_file}"
        assert "models" in calc, f"Missing 'models' field in {calc_file}"
        
        # Check Serpent model is defined
        assert "Serpent" in calc["models"], f"Missing 'Serpent' model in {calc_file}"
        
        print("✓")
    
    print("  All calculator files valid!\n")


def test_calculator_scripts():
    """Test that calculator shell scripts exist and are executable."""
    print("Testing calculator shell scripts...")
    
    scripts = [
        ".fz/calculators/Serpent.sh"
    ]
    
    for script_file in scripts:
        print(f"  Checking {script_file}...", end=" ")
        
        # Check file exists
        assert os.path.exists(script_file), f"File not found: {script_file}"
        
        # Check if executable
        assert os.access(script_file, os.X_OK), f"Script not executable: {script_file}"
        
        print("✓")
    
    print("  All calculator scripts valid!\n")


def test_example_files():
    """Test that example files exist."""
    print("Testing example files...")
    
    examples = [
        "examples/Serpent/input.inp",
        "examples/Serpent/input_res.m"
    ]
    
    for example_file in examples:
        print(f"  Checking {example_file}...", end=" ")
        assert os.path.exists(example_file), f"File not found: {example_file}"
        print("✓")
    
    print("  All example files present!\n")


def test_serpent_input_syntax():
    """Test that the example Serpent input file has valid fz variable syntax."""
    print("Testing Serpent input file syntax...")
    
    input_file = "examples/Serpent/input.inp"
    print(f"  Checking {input_file}...", end=" ")
    
    with open(input_file, 'r') as f:
        content = f.read()
    
    # Check for fz variable markers
    assert "${enrichment}" in content, "Variable ${enrichment} not found"
    assert "${water_density}" in content, "Variable ${water_density} not found"
    assert "${fuel_radius}" in content, "Variable ${fuel_radius} not found"
    
    # Check that Serpent comment character is used
    assert "%" in content, "Serpent comment character (%) not found"
    
    print("✓")
    print("  Serpent input syntax valid!\n")


def test_serpent_results_parsing():
    """Test that serpentTools can parse the mock result file."""
    print("Testing serpentTools result parsing...")
    
    try:
        import serpentTools
        import json
        print("  serpentTools module found ✓")
        
        res_file = "examples/Serpent/input_res.m"
        print(f"  Parsing {res_file}...", end=" ")
        
        res = serpentTools.read(res_file)
        
        # Check that key results are available
        assert 'absKeff' in res.resdata, "absKeff not found in results"
        assert 'anaKeff' in res.resdata, "anaKeff not found in results"
        assert 'colKeff' in res.resdata, "colKeff not found in results"
        assert 'impKeff' in res.resdata, "impKeff not found in results"
        
        # Check keff values are reasonable (around 1.0)
        # The array format may vary: either [value, error] or just [value]
        keff_data = res.resdata['absKeff']
        keff = keff_data[0] if keff_data.ndim == 1 else keff_data[0, 0]
        assert 0.5 < keff < 2.0, f"Unreasonable keff value: {keff}"
        
        print("✓")
        print(f"  Parsed keff = {keff}")
        
        # Test JSON output format
        print("  Testing JSON output format...", end=" ")
        absKeff_json = json.dumps(res.resdata['absKeff'].tolist())
        assert absKeff_json.startswith('['), "absKeff should be JSON array"
        parsed = json.loads(absKeff_json)
        assert isinstance(parsed, list), "absKeff JSON should parse to list"
        print("✓")
        
        # Test burnup/burnDays (may be empty for non-depletion cases)
        print("  Testing burnup/burnDays output...", end=" ")
        burnup_data = res.resdata.get('burnup', [])
        burnup_json = json.dumps(burnup_data.tolist() if hasattr(burnup_data, 'tolist') else [])
        assert burnup_json.startswith('['), "burnup should be JSON array"
        
        burnDays_data = res.resdata.get('burnDays', [])
        burnDays_json = json.dumps(burnDays_data.tolist() if hasattr(burnDays_data, 'tolist') else [])
        assert burnDays_json.startswith('['), "burnDays should be JSON array"
        print("✓")
        
        print("  serpentTools parsing successful!\n")
        
    except ImportError:
        print("  serpentTools module not installed - skipping parsing tests")
        print("  (Install with: pip install serpentTools)\n")


def run_output_commands(directory):
    """Run the output commands of the model in `directory` (as fz does) and return {name: parsed JSON}."""
    import subprocess
    with open(".fz/models/Serpent.json") as f:
        outputs = json.load(f)["output"]
    results = {}
    for name, command in outputs.items():
        r = subprocess.run(command, shell=True, cwd=directory, capture_output=True, text=True)
        assert r.returncode == 0, f"output command {name} failed: {r.stderr}"
        results[name] = json.loads(r.stdout)
    return results


def test_model_output_commands():
    """Test the output commands of the model on result files (standard library only, no serpentTools)."""
    print("Testing model output commands...")
    import shutil

    with tempfile.TemporaryDirectory() as tmpdir:
        print("  Single result block (criticality run)...", end=" ")
        shutil.copy("examples/Serpent/input_res.m", os.path.join(tmpdir, "input.inp_res.m"))
        out = run_output_commands(tmpdir)
        assert out["absKeff"] == [1.15295, 0.00094], f"absKeff = {out['absKeff']}"
        assert out["anaKeff"][:2] == [1.15583, 0.00176] and len(out["anaKeff"]) == 6, f"anaKeff = {out['anaKeff']}"
        assert out["impKeff"] == [1.15295, 0.00094] and out["colKeff"] == [1.15307, 0.0017]
        assert out["burnup"] == [] and out["burnDays"] == [], "burnup / burnDays must be empty without depletion"
        print("✓")

        print("  Several result blocks (one per burnup step)...", end=" ")
        text = open("examples/Serpent/input_res.m").read()
        with open(os.path.join(tmpdir, "input.inp_res.m"), "w") as f:
            f.write(text + text.replace("1.15295E+00", "1.10000E+00"))
        out = run_output_commands(tmpdir)
        assert out["absKeff"] == [[1.15295, 0.00094], [1.1, 0.00094]], f"absKeff = {out['absKeff']}"
        print("✓")

        print("  Missing result file...", end=" ")
        os.remove(os.path.join(tmpdir, "input.inp_res.m"))
        out = run_output_commands(tmpdir)
        assert all(v == [] for v in out.values()), f"expected empty outputs, got {out}"
        print("✓")

    print("  Model output commands OK!\n")


def test_calculator_errors():
    """Test that the calculator script reports Serpent failures (exit code and stderr) and finds SERPENT_EXE."""
    print("Testing calculator script error handling (fake Serpent executables)...")
    import subprocess

    script = os.path.abspath(".fz/calculators/Serpent.sh")
    fakes = {
        # Serpent 2 prints input errors on stdout and exits with 255
        "input_error": 'echo "Input error in parameter \\"therm\\" on line 43 in file \\"$1\\":"\n'
                       'echo; echo "S(a,b) data lwe7.00t not found in libraries"; exit 255\n',
        # a crash without a message and without result file, but exit code 0
        "no_result": 'echo "Transport cycle aborted"; exit 0\n',
        "ok": 'echo "Transport cycle completed in 1.0 seconds."; echo "ABS_KEFF (idx, [1: 2]) = [ 1.0 0.001 ];" > "$1_res.m"\n',
    }
    with tempfile.TemporaryDirectory() as tmpdir:
        open(os.path.join(tmpdir, "input.inp"), "w").write("% test\n")
        for case, body in fakes.items():
            exe = os.path.join(tmpdir, f"sss2_{case}")
            with open(exe, "w") as f:
                f.write("#!/bin/bash\n" + body)
            os.chmod(exe, 0o755)
            print(f"  {case}...", end=" ")
            r = subprocess.run(["bash", script, "input.inp"], cwd=tmpdir, capture_output=True, text=True,
                               env=dict(os.environ, SERPENT_EXE=exe))
            if case == "ok":
                assert r.returncode == 0, f"expected success, got {r.returncode}: {r.stderr}"
            else:
                assert r.returncode != 0, f"{case}: failure not reported (exit code 0)"
                assert "Serpent failed" in r.stderr, f"{case}: no error message on stderr: {r.stderr!r}"
            if case == "input_error":
                assert "lwe7.00t not found" in r.stderr, f"Serpent message missing from stderr: {r.stderr!r}"
            assert not os.path.exists(os.path.join(tmpdir, "PID")), "PID file left behind"
            print("✓")

        print("  executable not found...", end=" ")
        r = subprocess.run(["bash", script, "input.inp"], cwd=tmpdir, capture_output=True, text=True,
                           env=dict(os.environ, SERPENT_EXE=os.path.join(tmpdir, "no_such_sss2")))
        assert r.returncode == 127 and "SERPENT_EXE" in r.stderr, f"got {r.returncode}: {r.stderr!r}"
        print("✓")

    print("  Calculator error handling OK!\n")


def test_with_fz():
    """Test integration with fz framework (if available)."""
    print("Testing fz framework integration...")
    
    try:
        import fz
        print("  fz module found ✓")
        
        # Test parsing input file
        print("  Testing fz.fzi() on input.inp...", end=" ")
        variables = fz.fzi("examples/Serpent/input.inp", "Serpent")
        
        assert "enrichment" in variables, "Variable 'enrichment' not found in parsed input"
        assert "water_density" in variables, "Variable 'water_density' not found in parsed input"
        assert "fuel_radius" in variables, "Variable 'fuel_radius' not found in parsed input"
        print("✓")
        
        # Test compiling input file
        print("  Testing fz.fzc() compilation...", end=" ")
        with tempfile.TemporaryDirectory() as tmpdir:
            fz.fzc(
                "examples/Serpent/input.inp",
                {
                    "enrichment": 0.04,
                    "u238_fraction": 0.8415,
                    "water_density": 0.72,
                    "water_temp": 600,
                    "fuel_radius": 0.41,
                    "clad_inner_radius": 0.42,
                    "clad_outer_radius": 0.475,
                    "pitch_half": 0.63,
                    "neutrons_per_cycle": 50000,
                    "active_cycles": 200,
                    "inactive_cycles": 20,
                    "seed": 12345
                },
                "Serpent",
                output_dir=tmpdir
            )
            
            # Check compiled file exists (it may be in a subdirectory)
            compiled_file = None
            for root, dirs, files in os.walk(tmpdir):
                if "input.inp" in files:
                    compiled_file = os.path.join(root, "input.inp")
                    break
            assert compiled_file is not None, "Compiled file not created"
            
            # Check variables were substituted
            with open(compiled_file, 'r') as f:
                content = f.read()
                assert "0.04" in content, "Variable enrichment not substituted"
                assert "0.72" in content, "Variable water_density not substituted"
                assert "0.41" in content, "Variable fuel_radius not substituted"
                assert "${enrichment}" not in content, "Variable marker ${enrichment} still present"
                assert "${water_density}" not in content, "Variable marker ${water_density} still present"
        print("✓")
        
        print("  fz integration tests passed!\n")
        
    except ImportError:
        print("  fz module not installed - skipping integration tests")
        print("  (Install with: pip install git+https://github.com/Funz/fz.git)\n")


def main():
    """Run all tests."""
    print("=" * 70)
    print("fz-Serpent Plugin Test Suite")
    print("=" * 70)
    print()
    
    # Change to repository root if needed
    if not os.path.exists(".fz"):
        if os.path.exists("../fz-Serpent/.fz"):
            os.chdir("../fz-Serpent")
        else:
            print("Error: Could not find .fz directory")
            print("Please run this script from the fz-Serpent repository root")
            return 1
    
    try:
        test_model_files()
        test_calculator_files()
        test_calculator_scripts()
        test_example_files()
        test_serpent_input_syntax()
        test_serpent_results_parsing()
        test_model_output_commands()
        test_calculator_errors()
        test_with_fz()
        
        print("=" * 70)
        print("All tests passed! ✓")
        print("=" * 70)
        return 0
        
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
