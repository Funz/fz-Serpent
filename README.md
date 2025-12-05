# fz-Serpent

A [Funz](https://github.com/Funz/fz) plugin for running parametric studies with the [Serpent](https://serpent.vtt.fi/) Monte Carlo reactor physics code.

## Overview

This plugin enables you to:
- Define input parameters in Serpent input files using `${variable}` syntax
- Run parametric sweeps and sensitivity analyses
- Automatically extract key results (k-effective, etc.) using [serpentTools](https://serpent-tools.readthedocs.io/)

## Features

### Input Syntax
- **Variable syntax**: `${variable_name}` (e.g., `${enrichment}`)
- **Formula syntax**: `@{formula}` (e.g., `@{1-enrichment}`)
- **Comment character**: `%` (Serpent's native comment character)

### Supported Output Variables

The plugin automatically extracts these output variables from Serpent result files (`*_res.m`):

| Variable | Description |
|----------|-------------|
| `absKeff` | Absorption-based effective multiplication factor |
| `absKeff_err` | Relative error of absKeff |
| `anaKeff` | Analog k-effective estimate |
| `anaKeff_err` | Relative error of anaKeff |
| `colKeff` | Collision-based k-effective |
| `colKeff_err` | Relative error of colKeff |
| `impKeff` | Implicit k-effective estimate |
| `impKeff_err` | Relative error of impKeff |

## Requirements

- [Funz/fz](https://github.com/Funz/fz) framework
- [Serpent 2](https://serpent.vtt.fi/) Monte Carlo code (for actual calculations)
- [serpentTools](https://serpent-tools.readthedocs.io/) Python package (for result parsing)

## Installation

1. Install the fz framework:
```bash
pip install git+https://github.com/Funz/fz.git
```

2. Install serpentTools for result parsing:
```bash
pip install serpentTools
```

3. Clone this repository:
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

print(results[['enrichment', 'absKeff', 'absKeff_err']])
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

This plugin uses [serpentTools](https://serpent-tools.readthedocs.io/) to parse Serpent output files. The `*_res.m` files contain all criticality results.

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

## Configuring Serpent Path

The calculator script looks for Serpent in the following locations:
1. `sss2` command in PATH
2. `serpent` command in PATH
3. `/opt/serpent/bin/sss2`
4. `$HOME/serpent/bin/sss2`

To use a custom Serpent installation, modify `.fz/calculators/Serpent.sh`.

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
# Install test dependencies
pip install serpentTools

# Run tests
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