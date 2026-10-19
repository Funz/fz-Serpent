# fz-Serpent

A [Funz](https://github.com/Funz/fz) plugin for running parametric studies with the [Serpent](https://serpent.vtt.fi/) Monte Carlo reactor physics code.

## Overview

This plugin enables you to:
- Define input parameters in Serpent input files using `${variable}` syntax
- Run parametric sweeps and sensitivity analyses
- Automatically extract key results (k-effective, etc.) from the `*_res.m` result files

## Features

### Input Syntax
- **Variable syntax**: `${variable_name}` (e.g., `${enrichment}`)
- **Formula syntax**: `@{formula}` (e.g., `@{1-enrichment}`)
- **Comment character**: `%` (Serpent's native comment character)

### Supported Output Variables

The plugin automatically extracts these output variables from Serpent result files (`*_res.m`). All outputs are formatted as JSON arrays/matrices for easy parsing: a list of values for a single result block (criticality run), one list per burnup step for depletion runs, `[]` when the variable is absent. The output commands use only the Python standard library (any `python3`), with the same values and shapes as `serpentTools` `resdata`.

| Variable | Description |
|----------|-------------|
| `absKeff` | Absorption-based k-effective [value, rel_error] per burnup step |
| `anaKeff` | Analog k-effective estimate [value, rel_error, ...] per burnup step |
| `colKeff` | Collision-based k-effective [value, rel_error] per burnup step |
| `impKeff` | Implicit k-effective estimate [value, rel_error] per burnup step |
| `burnup` | Burnup values [MWd/kgU, ...] per burnup step (empty for non-depletion) |
| `burnDays` | Burnup time [days] per burnup step (empty for non-depletion) |

## Requirements

- [Funz/fz](https://github.com/Funz/fz) framework
- [Serpent 2](https://serpent.vtt.fi/) Monte Carlo code (for actual calculations)
- `python3` in PATH (standard library only) for the output commands
- optional: [serpentTools](https://serpent-tools.readthedocs.io/) for your own post-processing (see [Result Parsing](#result-parsing))

## Installation

1. Install the fz framework:
```bash
pip install git+https://github.com/Funz/fz.git
```

2. Clone this repository:
```bash
git clone https://github.com/Funz/fz-Serpent.git
cd fz-Serpent
```

## Usage

### With fz Python API

```python
import fz

# Example: Run parametric study varying fuel enrichment
results = fz.fzr(
    input_path="examples/Serpent/input.inp",
    input_variables={
        "enrichment": [0.03, 0.04, 0.05],
        "u238_fraction": [0.8515, 0.8415, 0.8315],
        "water_density": [0.72],
        "water_temp": [600],
        "fuel_radius": [0.41],
        "clad_inner_radius": [0.42],
        "clad_outer_radius": [0.475],
        "pitch_half": [0.63],
        "neutrons_per_cycle": [50000],
        "active_cycles": [200],
        "inactive_cycles": [20],
        "seed": [12345]
    },
    model="Serpent",
    calculators="localhost_Serpent",
    results_dir="my_results"
)

# absKeff = [k, relative standard deviation]
print(results[['enrichment', 'absKeff', 'status', 'error']])
```

### Directory Structure

```
fz-Serpent/
├── .fz/
│   ├── models/
│   │   └── Serpent.json        # Model configuration
│   └── calculators/
│       ├── Serpent.sh          # Calculator script
│       └── localhost_Serpent.json
├── examples/
│   └── Serpent/
│       ├── input.inp           # Example Serpent input file
│       └── input_res.m         # Example result file (for testing)
├── tests/
│   └── test_plugin.py          # Test suite
├── README.md
├── LICENSE
└── .gitignore
```

## Example Input File

```serpent
% UOX Fuel Pin Cell - fz Parametric Study
% Variables are defined using ${variable_name} syntax

% --- UOX fuel material ---
mat fuel -10.5 tmp 900
92235.09c -${enrichment}
92238.09c -${u238_fraction}
8016.09c  -0.1185

% --- Water moderator/coolant ---
mat water -${water_density} moder lwtr 1001 tmp ${water_temp}
1001.06c  2
8016.06c  1

% --- Geometry ---
surf 1 cyl 0.0 0.0 ${fuel_radius}
surf 2 cyl 0.0 0.0 ${clad_inner_radius}
surf 3 cyl 0.0 0.0 ${clad_outer_radius}
surf 4 sqc 0.0 0.0 ${pitch_half}

% --- Run settings ---
set pop ${neutrons_per_cycle} ${active_cycles} ${inactive_cycles}
set seed ${seed}
```

## Result Parsing

The `*_res.m` files contain all criticality results. The plugin reads them without any dependency; for further
post-processing, [serpentTools](https://serpent-tools.readthedocs.io/) can be used. Note: serpentTools 0.11.0 fails with
numpy >= 2.3 (`TypeError: only 0-dimensional arrays can be converted to Python scalars`); install it with
`pip install serpentTools "numpy<2.3"`.

Example of manually reading results:

```python
import serpentTools

# Read Serpent result file
res = serpentTools.read('input_res.m')

# Access k-effective values
keff = res.resdata['absKeff'][0, 0]      # value
keff_err = res.resdata['absKeff'][0, 1]  # relative error

print(f"k-eff = {keff:.5f} ± {keff * keff_err:.5f}")
```

## Configuring Serpent

The calculator script (`.fz/calculators/Serpent.sh`) is configured by environment variables:

| Variable | Meaning |
|----------|---------|
| `SERPENT_EXE` | Serpent executable. Default: `sss2` or `serpent` in PATH, then `/opt/serpent/bin/sss2`, `$HOME/serpent/bin/sss2` |
| `SERPENT_OMP` | number of OpenMP threads, passed as `-omp N` (default 1) |
| `SERPENT_DATA` | directory of the cross section data (read by Serpent: relative `set acelib` / `set declib` names) |
| `SERPENT_ACELIB` | default cross section directory file, used when the input has no `set acelib` (read by Serpent) |

```bash
export SERPENT_EXE=/path/to/sss2 SERPENT_OMP=4
export SERPENT_DATA=/path/to/xsdata SERPENT_ACELIB=sss_endfb7u.xsdata
```

The example input has no `set acelib` (it relies on `SERPENT_ACELIB`) and uses the thermal scattering library
`lwe7.00t` (`therm lwtr lwe7.00t`): adapt this name to the S(α,β) data of your cross section directory file (for
example `h-h2o.15t` at 600 K with ENDF/B-VIII.0).

### Error reporting

A calculation is reported as failed (`status = failed`) when Serpent exits with a non-zero code, when its output
contains an `Input error`, `Fatal error`, `Tracking error` or `Geometry error:` message, or when no `*_res.m` file was
written. The Serpent message is written to stderr, so it appears in the `error` column of the fz results, e.g.:

```
Command failed with exit code 255. stderr: Serpent failed (exit code 255): Input error in parameter "therm" on line 43 in file "input.inp":
S(a,b) data lwe7.00t not found in libraries
```

Note: with group constant generation on (Serpent default), the number of active cycles must be a multiple of 20;
add `set gcu -1` to the input if group constants are not needed.

## Remote Execution

To run calculations on a remote server with Serpent installed:

```python
results = fz.fzr(
    input_path="input.inp",
    input_variables={"enrichment": [0.03, 0.04, 0.05]},
    model="Serpent",
    calculators="ssh://user@hpc-server.edu/bash /path/to/calculators/Serpent.sh",
    results_dir="remote_results"
)
```

## Running Tests

```bash
# Optional test dependencies (the serpentTools test is skipped without it)
pip install serpentTools "numpy<2.3"

# Run tests (model files, output commands, calculator error handling with fake executables, fz integration)
python tests/test_plugin.py
```

## References

- [Serpent Monte Carlo Code](https://serpent.vtt.fi/)
- [Serpent Documentation](https://serpent.vtt.fi/docs/index.html)
- [serpentTools Documentation](https://serpent-tools.readthedocs.io/)
- [serpentTools ResultsReader Example](https://serpent-tools.readthedocs.io/en/master/examples/ResultsReader.html)
- [Funz/fz Framework](https://github.com/Funz/fz)

## License

BSD 3-Clause License. See [LICENSE](LICENSE) file.

## Related Projects

- [Funz/fz](https://github.com/Funz/fz) - Main framework
- [Funz/fz-Model](https://github.com/Funz/fz-Model) - Plugin template
- [Funz/fz-Scale](https://github.com/Funz/fz-Scale) - SCALE code plugin