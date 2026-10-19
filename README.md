# fz-Serpent

[fz](https://github.com/Funz/fz) wrapper for the [Serpent 2](https://serpent.vtt.fi/docs/)
continuous-energy Monte Carlo reactor physics code: parameterize a Serpent input, run
parametric studies or designs of experiments locally, over SSH or on SLURM, and get
k-eff (and its statistical error), β-eff, burnup... as DataFrame columns.

## Quickstart

```bash
pip install "funz-fz>=1.2"
fz install model Serpent          # into ./.fz/  (add --global for ~/.fz/)
```

```python
import fz

results = fz.fzr(
    "input.inp",                                  # e.g. examples/Serpent/input.inp
    {"enrichment": [0.03, 0.04, 0.05]},           # other variables keep their defaults
    model="Serpent",                              # calculator localhost_Serpent is found automatically
)
print(results[["enrichment", "absKeff", "absKeff_err"]])
```

```bash
fzr input.inp --model Serpent -v '{"enrichment": [0.03, 0.04, 0.05]}' --format table
```

## Requirements

- fz ≥ 1.2 (`pip install funz-fz`) — output parsing uses fz's built-in `python://`
  extraction, no other Python package is needed (serpentTools is **not** required).
- Serpent 2 (licensed by VTT through the NEA Data Bank / RSICC) with its nuclear data:
  either declared in the input (`set acelib`, `set declib`, `set nfylib`) or through the
  environment variables Serpent reads itself: `SERPENT_DATA` (search directory, so that
  data files can be named without path), `SERPENT_ACELIB`, and since Serpent 2.2.0
  `SERPENT_DECLIB`, `SERPENT_NFYLIB`; the `set` cards of the input override them.

## Input syntax

| Element | Syntax | Example |
|---|---|---|
| Variable | `${name}` or `${name~default}` | `92235.09c -${enrichment~0.04}` |
| Formula (Python) | `@{expression}` | `92238.09c -@{round(0.8815 - $enrichment, 6)}` |
| Formula helper line | `%@ ...` | `%@ def ratio(e): return e / (1 - e)` |
| Comment | `%` (Serpent's own) | |

`$` and `@` have no meaning in Serpent input, and helper lines start with Serpent's comment
character `%`, so a compiled input is plain Serpent. Text in comments is parsed too: do not
write `${...}` in a comment unless it is a variable. Model: [`.fz/models/Serpent.json`](.fz/models/Serpent.json).

## Outputs

Read from `<input>_res.m`. For a criticality run each output is a number; for a burnup
(depletion) run it is a list with one value per burnup step. `_err` values are Serpent's
**relative** statistical errors (1σ). An output absent from the result file (e.g. `burnup`
without depletion, `betaEff` without the corresponding calculation) is `None`.

| Output | `_res.m` key | Description |
|---|---|---|
| `absKeff`, `absKeff_err` | `ABS_KEFF` | absorption estimate of k-eff |
| `anaKeff`, `anaKeff_err` | `ANA_KEFF` | analog estimate of k-eff |
| `impKeff`, `impKeff_err` | `IMP_KEFF` | implicit estimate of k-eff |
| `colKeff`, `colKeff_err` | `COL_KEFF` | collision estimate of k-eff |
| `absKinf`, `absKinf_err` | `ABS_KINF` | absorption estimate of k-inf |
| `betaEff`, `betaEff_err` | `BETA_EFF` | total effective delayed neutron fraction |
| `burnup` | `BURNUP` | burnup at the step (MWd/kgU), first of the two values |
| `burnDays` | `BURN_DAYS` | cumulative irradiation time (days) |
| `cpuTime` | `TOT_CPU_TIME` | total CPU time (minutes) |

Other quantities can be added without editing the model, e.g. from the CLI:

```bash
fzo 'results/*' --model Serpent \
    --output-cmd sixFfKeff="python://grep(r'^SIX_FF_KEFF\s.*?=\s*\[\s*(\S+)', 'input.inp_res.m')"
```

## Calculator

`localhost_Serpent` runs [`.fz/calculators/Serpent.sh`](.fz/calculators/Serpent.sh) in each
case directory. The script is configured by environment variables:

| Variable | Default | Role |
|---|---|---|
| `SERPENT_BIN` | `sss2`, then `sss`, then `serpent` in `PATH` | Serpent executable |
| `SERPENT_OMP` | (Serpent's default) | OpenMP threads, passed as `-omp N` |
| `SERPENT_ARGS` | | extra command-line options (e.g. `-nofatal`) |
| `SERPENT_INPUT` | first `*.inp`, else first file | main input when the input is a directory with `include`d files |

A case fails (and is retried on another calculator) when Serpent exits with an error or
writes no `_res.m`. A stale `_res.m` is removed before each run, as Serpent appends to it.
Keep `max_workers × SERPENT_OMP` within the number of cores.

Remote execution reuses the same script, for instance:

```python
fz.fzr("input.inp", {"enrichment": [0.03, 0.05]}, model="Serpent",
       calculators="ssh://user@cluster/bash /path/to/Serpent.sh")
# or SLURM: "slurm://user@cluster:partition/bash /path/to/Serpent.sh"
```

## Repository layout

```
.fz/models/Serpent.json                 model (syntax + output parsing)
.fz/calculators/Serpent.sh              runner script
.fz/calculators/localhost_Serpent.json  local calculator alias
examples/Serpent/input.inp              UOX pin cell, parameterized
examples/Serpent/input_res.m            result file of a Serpent 2.1.30 run (parsing tests)
tests/test_plugin.py                    model/parsing tests (pytest)
tests/test.sh                           end-to-end test: install, fzi, fzc, run, fzo, fzr
tests/mock/sss2                         fake Serpent for CI
tests/data/depletion_res.m              synthetic 3-step depletion result
```

## Tests

```bash
python -m pytest tests/
bash tests/test.sh                      # uses tests/mock/sss2
FZ_SERPENT_MOCK=0 bash tests/test.sh    # uses the real Serpent (sss2 or SERPENT_BIN)
```

## References

- Serpent documentation: <https://serpent.vtt.fi/docs/> — in particular
  [Running Serpent](https://serpent.vtt.fi/docs/user_guide/running_overview.html),
  [Data libraries](https://serpent.vtt.fi/docs/user_guide/nuclear_data.html),
  [Standard output](https://serpent.vtt.fi/docs/user_guide/standard_output.html),
  [Burnup output](https://serpent.vtt.fi/docs/user_guide/burnup_output.html)
- fz documentation: <https://github.com/Funz/fz/tree/main/doc>

## License

BSD 3-Clause, see [LICENSE](LICENSE).
