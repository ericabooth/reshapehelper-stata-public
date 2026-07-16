# ReshapeHelper - Stata program to auto build and diagnose -reshape- syntax

Diagnose the dataset and **suggest** the likely `reshape`
command based on dataset shape (or minimal guidance). Does not run reshape, but provides code to run successful -reshape-

`reshape` is the Stata command most likely to send an analyst to a
discussion board: is this wide or long, which variables are `i` and `j`,
where does `string` go, why `r(9)`, why "no xij variables found"?
`reshapehelper` answers those questions **before anything is reshaped**, and
it never modifies your data.

<img width="1214" height="640" alt="reshapehelper" src="https://github.com/user-attachments/assets/5e2ebc85-fca0-4546-8f57-c725c98e52a4" />


## What it does

1. **Scans variable names** for wide patterns: numeric suffixes
   (`inc80 inc81`), string suffixes (`bp_before bp_after`), a j buried
   mid-name (`inc80r` - the `@` notation), a j hiding in the *prefix*
   (`qld_p nsw_p vic_p`), and doubly-wide names carrying two indices
   (`ht_k1_t2`).
2. **Hunts for i and j**- declared structure first (`xtset`/`tsset` panel
   and time variables, the `svyset` PSU), then `isid` tests over id-looking
   variables, then bounded single-and-pair searches (which is how a compound
   i like *(household, year)* gets found).
3. **Composes the command and dry-runs it** on a sample inside
   `preserve`/`restore`, iterating on reshape's own errors: `r(109)`/`r(498)`
   add `string`, `r(110)` renames a colliding j, `r(9)` in a widening
   triggers a duplicates diagnosis and one attempt to extend `i()`.
4. **Reports three ways**:
   - an ASCII **before/after diagram** in the style of the reshape help
     file, built from your real variable names and values- the AFTER box is
     the dry run's actual result;
   - the **suggested syntax with a verdict** (`dry-run PASSED` / `FAILED
     r(#)`), plus notes and cautions- or, when it cannot discern the
     design, a **numbered checklist** of what to fix or supply;
   - the command **ready to use**: `r(cmd)` (+ `r(cmd2)` for chained pairs),
     the global `$reshapehelper_cmd`, an unwrapped SMCL file, and
     click-to-run / click-to-view links in the Results window.

For a doubly-wide layout it suggests and tests the two chained reshapes.

When the job is really a transpose (observations stored as columns) it says
so and points at `xpose` (`sxpose` for strings).

## Install

`reshapehelper` is self-contained ... the command and its help file, with no
external Stata dependencies.

```stata
net install reshapehelper, from("https://raw.githubusercontent.com/ericabooth/reshapehelper-stata-public/main/") replace force
help reshapehelper
```

The package ships `reshapehelper.pkg` and `stata.toc`, so Stata's installer
picks up every file in one call; no manual `adopath` step is needed. To pull a
local copy of the worked examples, `net get` the ancillary do-file:

```stata
net get reshapehelper, from("https://raw.githubusercontent.com/ericabooth/reshapehelper-stata-public/main/")
```

## Quick start

Each block below loads its own data, so you can paste any one of them on its
own.

```stata
* just ask -- suggests and dry-runs, then run the suggestion:
sysuse bpwide, clear
reshapehelper
* -> reshape long bp_, i(patient) j(period) string
$reshapehelper_cmd
```

```stata
* tell it what you know; the dry run figures out the rest (here it discovers
* the string option by iterating on reshape's r(498)):
clear
input id kids incm incf
1 0 5000 5500
2 1 2000 2200
end
reshapehelper, to(long) stubs(inc) i(id) j(sex)
$reshapehelper_cmd
```

```stata
* going wide, with a messy string j ("New York"): the pre-clean line is
* written for you and returned in r(preclean):
clear
input year str12 state pop
2020 "New York" 20.2
2020 "Texas" 29.1
2021 "New York" 19.8
2021 "Texas" 29.5
end
reshapehelper, to(wide) j(state)
`r(preclean)'
$reshapehelper_cmd
```

```stata
* doubly wide (ht_k1_t1 ... ht_k2_t2): two chained commands, both tested:
clear
input famid ht_k1_t1 ht_k1_t2 ht_k2_t1 ht_k2_t2
1 3.1 3.6 4.0 4.4
2 3.3 3.8 4.1 4.6
end
reshapehelper
$reshapehelper_cmd
$reshapehelper_cmd2
```

## Syntax

```
reshapehelper [long|wide] [varlist] [, to(long|wide) i(varlist)
    j(name|varname) stubs(names) sample(#) notest
    smcl(filename) replace global(name) detail]
```

Everything is optional; a bare `reshapehelper` diagnoses the data in memory.
See `help reshapehelper` for every option, and run
`example_reshapehelper.do` for a seventeen-scenario tour (five tiers) from
the textbook case to inconsistent stubs, the `inc2` trap, prefix-j names,
crossed factors, duplicate (i, j) pairs, wide-long panels, doubly-wide
names, long-long → wide-wide, and the transpose case.

The globals mirror the **last run**: a run with no second step clears
`$reshapehelper_cmd2`, and a run that ends in the checklist clears both, so
a stale command from an earlier dataset can never fire in a pipeline.

## Stored results

| Result | Meaning |
| ------ | ------- |
| `r(status)` | `ok`, `blocked` (dry run failed; see `r(diagnosis)`), or `needinfo` (checklist shown) |
| `r(direction)` | `wide2long`, `long2wide`, `doubly`, `unknown` |
| `r(cmd)`, `r(cmd2)` | the suggested command(s); also `$reshapehelper_cmd`(`2`) |
| `r(preclean)` | a cleaning line to run first (e.g., strip spaces from a string j) |
| `r(i)`, `r(j)`, `r(stubs)` | the pieces the suggestion uses |
| `r(note)`, `r(caution)`, `r(diagnosis)` | the annotations printed under the suggestion |
| `r(tested)`, `r(rc)` | dry-run verdict and final return code |
| `r(smcl)` | path of the unwrapped-suggestion SMCL file |
| `r(xpose)` | 1 when the layout smells like a transpose job |
| `r(sparse)` | a would-be identifier set aside as too sparse (returned only when that is why no command was found) |

## Design limits (v1.0.0, deliberate)

- **Suggestions are advisory.** A dry run proves the command *runs* on a
  sample; only you can say the result *means* what you need. Cautions flag
  the known silent traps: small consecutive suffixes that may be item
  numbers, and mixed suffix widths (a stray `inc2` beside `inc80–inc82`)
  where reshape runs happily and builds a mostly-missing j group.
- **Bare string suffixes are not guessed.** `incm`/`incf` are handled only
  through `stubs()`- automatic splitting of such names is the greedy
  matching the reshape manual itself warns about (stub `age`, j `nda`,
  courtesy of a variable named `agenda`).
- **One dimension per pass.** Doubly-wide names get the two-step chain;
  anything deeper gets the chain plus a rerun of `reshapehelper` on the
  intermediate result. It is built to be rerun until the note falls silent.
- Probes and the dry run use the first `sample(#)` rows (default 500), so a
  pathology that first appears deep in a tall dataset can escape the
  diagnosis. After your own failed attempt, `reshape error` lists the
  offending observations.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Eric A. Booth.

Support: eric.a.booth@gmail.com
