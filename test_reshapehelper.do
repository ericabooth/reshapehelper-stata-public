* ===========================================================================
* test_reshapehelper.do -- test battery for reshapehelper v1.0.0
* Run in batch from the package directory:
*     stata-mp -b do test_reshapehelper.do
* Judge the run by the log: no r(NNN) errors, no "assertion is false".
* ---------------------------------------------------------------------------
* Scenarios T1-T18 mirror the researched catalog: the [D] reshape manual
* examples, the Stata "problems with reshape" FAQ, UCLA OARC's doubly-wide
* FAQ, and Statalist threads (prefix-j, duplicate (i,j), composite factors,
* transpose confusion).  reshapehelper must never modify the data in memory;
* every scenario asserts the row/column counts afterward.
* ===========================================================================
* pkgroot is the package directory itself. The header says to run this from
* that directory, so the current working directory locates the package for
* both -adopath- and the scratch SMCL file below -- no hard-coded path, so the
* battery runs unchanged for anyone who clones this repo.
global pkgroot "`c(pwd)'"

version 16.0
clear all
set more off
set seed 20260715
adopath + "$pkgroot"

* ---------------------------------------------------------------------------
* T1. Classic wide -> long, numeric suffixes ([D] reshape Example 1)
* ---------------------------------------------------------------------------
clear
input id sex inc80 inc81 inc82
1 0 5000 5500 6000
2 1 2000 2200 3300
3 0 3000 2000 1000
end
reshapehelper
assert "`r(status)'"    == "ok"
assert "`r(direction)'" == "wide2long"
assert r(tested)        == 1
assert strpos(`"`r(cmd)'"', "reshape long inc, i(id) j(year)") > 0
assert `"$reshapehelper_cmd"' == `"`r(cmd)'"'
assert _N == 3 & c(k) == 5          // data untouched

* ---------------------------------------------------------------------------
* T2. Two stubs at once: inc AND ue ([D] reshape Example 1, full)
* ---------------------------------------------------------------------------
clear
input id sex inc80 inc81 inc82 ue80 ue81 ue82
1 0 5000 5500 6000 0 1 0
2 1 2000 2200 3300 1 0 0
3 0 3000 2000 1000 0 0 1
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape long inc ue, i(id) j(year)") > 0

* ---------------------------------------------------------------------------
* T3. Classic long -> wide ([D] reshape Example 1 reversed)
* ---------------------------------------------------------------------------
clear
input id year sex inc ue
1 80 0 5000 0
1 81 0 5500 1
1 82 0 6000 0
2 80 1 2000 1
2 81 1 2200 0
2 82 1 3300 0
3 80 0 3000 0
3 81 0 2000 0
3 82 0 1000 1
end
reshapehelper, to(wide)
assert "`r(status)'"    == "ok"
assert "`r(direction)'" == "long2wide"
assert r(tested)        == 1
assert strpos(`"`r(cmd)'"', "reshape wide inc ue, i(id) j(year)") > 0
assert _N == 9 & c(k) == 5

* ---------------------------------------------------------------------------
* T4. String suffixes after an underscore (sysuse bpwide)
* ---------------------------------------------------------------------------
sysuse bpwide, clear
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape long bp_, i(patient) j(period) string") > 0

* ---------------------------------------------------------------------------
* T5. @ mid-name stubs beside plain stubs ([D] reshape Example 7: inc@r + ue)
* ---------------------------------------------------------------------------
clear
input id sex inc80r inc81r inc82r ue80 ue81 ue82
1 0 5000 5500 6000 0 1 0
2 1 2000 2200 3300 1 0 0
3 0 3000 2000 1000 0 0 1
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "inc@r") > 0
assert strpos(`"`r(cmd)'"', "ue") > 0
assert strpos(`"`r(cmd)'"', "j(year)") > 0

* ---------------------------------------------------------------------------
* T6. Unbalanced stubs: ue81 does not exist ([D] reshape Example 6)
* ---------------------------------------------------------------------------
clear
input id sex inc80 inc81 inc82 ue80 ue82
1 0 5000 5500 6000 0 0
2 1 2000 2200 3300 1 0
3 0 3000 2000 1000 0 1
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape long inc ue, i(id) j(year)") > 0
assert strpos(`"`r(note)'"', "unbalanced") > 0

* ---------------------------------------------------------------------------
* T7. The inc2 trap: a stray same-stub variable ([D] reshape, j() values).
*     The dry run PASSES (reshape happily builds a j=2 group), so the
*     mixed-width caution is the safety net.
* ---------------------------------------------------------------------------
clear
input id sex inc80 inc81 inc82 inc2
1 0 5000 5500 6000 1
2 1 2000 2200 3300 0
3 0 3000 2000 1000 1
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(caution)'"', "widths differ") > 0
assert strpos(`"`r(caution)'"', "restrict j") > 0

* ---------------------------------------------------------------------------
* T8. Inconsistent stub names: inc80 / income81 / incm82 (UVA + Stata FAQ).
*     No family forms, so the helper must say so and coach a rename.
* ---------------------------------------------------------------------------
clear
input id sex inc80 income81 incm82
1 0 5000 5500 6000
2 1 2000 2200 3300
3 0 3000 2000 1000
end
reshapehelper
assert "`r(status)'" == "needinfo"
assert `"`r(cmd)'"' == ""

* ---------------------------------------------------------------------------
* T9. String j containing spaces (Statalist r(111) thread): forced j(state)
*     must trigger the pre-clean line, the string option, and a passing test
* ---------------------------------------------------------------------------
clear
input year str12 state pop
2020 "New York" 20.2
2020 "Texas" 29.1
2021 "New York" 19.8
2021 "Texas" 29.5
end
reshapehelper, to(wide) j(state)
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "j(state) string") > 0
assert strpos(`"`r(preclean)'"', "subinstr") > 0
assert _N == 4 & c(k) == 3          // caller's data untouched (incl. spaces)
assert strpos(state[1], " ") > 0

* ---------------------------------------------------------------------------
* T10. Prefix-as-j: qld_p nsw_p vic_p (Statalist "no xij variables found")
* ---------------------------------------------------------------------------
clear
input year qld_p nsw_p vic_p
2018 4.9 7.9 6.4
2019 5.0 8.0 6.5
2020 5.1 8.1 6.6
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "@_p") > 0
assert strpos(`"`r(cmd)'"', "string") > 0

* ---------------------------------------------------------------------------
* T11. Duplicate (i, j) pairs block reshape wide (Statalist / manual Ex. 3):
*      the helper must diagnose, count, and hand back the remedy menu
* ---------------------------------------------------------------------------
clear
input id year inc
1 2019 45000
1 2020 47000
2 2019 32000
2 2019 32000
2 2020 33500
end
reshapehelper, to(wide)
assert "`r(status)'" == "needinfo"
assert strpos(`"`r(diagnosis)'"', "duplicates report") > 0
assert strpos(`"`r(diagnosis)'"', "collapse") > 0
assert strpos(`"`r(diagnosis)'"', "concat") > 0

* ---------------------------------------------------------------------------
* T12. Two crossed factors (Statalist animal/level/delay): the helper finds a
*      compound i and widens ONE factor, and its note points to the rest
* ---------------------------------------------------------------------------
clear
input animal s1level s1s2delay s2peakvalue
1 0 50 12.1
1 0 100 13.4
1 0 200 15.2
1 1 50 18.3
1 1 100 19.9
1 1 200 22.4
2 0 50 11.8
2 0 100 12.9
2 0 200 14.7
2 1 50 17.5
2 1 100 19.2
2 1 200 21.8
end
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape wide s2peakvalue") > 0
assert strpos(`"`r(note)'"', "concat") > 0

* ---------------------------------------------------------------------------
* T13. Doubly wide (UCLA FAQ): two digit runs in the names -> two chained
*      reshapes, both dry-run tested
* ---------------------------------------------------------------------------
clear
input famid ht_k1_t1 ht_k1_t2 ht_k2_t1 ht_k2_t2
1 3.1 3.6 4.0 4.4
2 3.3 3.8 4.1 4.6
3 3.0 3.5 3.9 4.3
end
reshapehelper
assert "`r(status)'"    == "ok"
assert "`r(direction)'" == "doubly"
assert r(tested)        == 1
assert `"`r(cmd2)'"' != ""
assert strpos(`"`r(cmd)'"',  "reshape long ht_k1_t ht_k2_t, i(famid)") > 0
assert strpos(`"`r(cmd2)'"', "reshape long ht_k@_t, i(famid") > 0
assert _N == 3 & c(k) == 5

* ---------------------------------------------------------------------------
* T14. Long-long to wide-wide, step one ([D] reshape second-level nesting):
*      compound i() found, low-cardinality factor left in i() flagged
* ---------------------------------------------------------------------------
clear
input hid str1 sex year inc
1 "f" 90 3200
1 "f" 91 4700
1 "m" 90 4500
1 "m" 91 4600
2 "f" 90 3600
2 "f" 91 3800
2 "m" 90 5100
2 "m" 91 5300
end
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape wide inc") > 0
assert `"`r(note)'"' != ""

* ---------------------------------------------------------------------------
* T15. Already-long tidy panel, no to(): the helper reads it as long and
*      offers the wide command
* ---------------------------------------------------------------------------
clear
input id year inc
1 80 5000
1 81 5500
1 82 6000
2 80 2000
2 81 2200
2 82 3300
end
reshapehelper
assert "`r(status)'"    == "ok"
assert "`r(direction)'" == "long2wide"
assert r(tested)        == 1

* ---------------------------------------------------------------------------
* T16. Transpose, not reshape (Statalist xpose thread): metrics as rows
* ---------------------------------------------------------------------------
clear
input str12 metric alpha beta gamma
"n"       100 200 150
"mean"    52.1 48.9 50.3
"missing" 3 7 5
end
reshapehelper
assert "`r(status)'" == "needinfo"
assert r(xpose) == 1

* ---------------------------------------------------------------------------
* T17. Wide-long panel honoring xtset: county-year rows with sector columns;
*      i() must include the existing time variable
* ---------------------------------------------------------------------------
clear
input county year emp_manuf emp_retail emp_gov
1 2019 120 340 210
1 2020 115 330 215
2 2019  80 210 150
2 2020  78 220 155
3 2019  60 190 120
3 2020  61 200 118
end
xtset county year
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape long emp_, i(county year)") > 0
assert strpos(`"`r(cmd)'"', "string") > 0
assert strpos(`"`r(note)'"', "SECOND long dimension") > 0

* ---------------------------------------------------------------------------
* T18. User-assisted bare string suffixes ([D] reshape Example 8: incm/incf):
*      stubs()+i()+j() supplied; the dry-run engine discovers the string
*      option by iterating on reshape's own r(498)
* ---------------------------------------------------------------------------
clear
input id kids incm incf
1 0 5000 5500
2 1 2000 2200
3 2 3000 2000
end
reshapehelper, to(long) stubs(inc) i(id) j(sex)
assert "`r(status)'" == "ok"
assert r(tested)     == 1
assert strpos(`"`r(cmd)'"', "reshape long inc, i(id) j(sex) string") > 0

* ---------------------------------------------------------------------------
* T19. Guardrails: shorthand tokens, bad options, empty data
* ---------------------------------------------------------------------------
sysuse bpwide, clear
reshapehelper long                    // bare-token shorthand for to(long)
assert "`r(status)'" == "ok"
capture reshapehelper, to(sideways)
assert _rc == 198
capture reshapehelper, sample(3)
assert _rc == 198
clear
capture reshapehelper
assert _rc == 2000

* ---------------------------------------------------------------------------
* T20. The SMCL suggestion file exists and holds the unwrapped command
* ---------------------------------------------------------------------------
clear
input id inc80 inc81
1 5000 5500
2 2000 2200
end
tempfile junk
reshapehelper, smcl("$pkgroot/scratch_suggestion.smcl") replace
assert "`r(status)'" == "ok"
confirm file "$pkgroot/scratch_suggestion.smcl"
file open fh using "$pkgroot/scratch_suggestion.smcl", read text
local found 0
file read fh line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "reshape long inc, i(id) j(year)") local found 1
    file read fh line
}
file close fh
assert `found' == 1
erase "$pkgroot/scratch_suggestion.smcl"

* ---------------------------------------------------------------------------
* T21. Edge sweep: hostile small/weird data must never crash, never touch
*      the data, and never leave a stale global
* ---------------------------------------------------------------------------
* (a) one observation, one variable -> graceful checklist
clear
set obs 1
gen x = 1
reshapehelper
assert inlist("`r(status)'", "needinfo", "ok")
assert _N == 1 & c(k) == 1

* (b) all-string dataset -> graceful
clear
input str5 a str5 b
"x" "y"
"z" "w"
end
reshapehelper
assert inlist("`r(status)'", "needinfo", "ok")
assert _N == 2 & c(k) == 2

* (c) strL beside wide stubs -> still suggests, strL skipped in probes
clear
input id inc80 inc81
1 5000 5500
2 2000 2200
end
gen strL comment = "free text " + string(id)
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested) == 1
assert strpos(`"`r(cmd)'"', "reshape long inc, i(id)") > 0
assert c(k) == 4

* (d) a variable named year already exists beside inc80-inc82: the proposed
*     j must dodge the collision and the dry run must still pass
clear
input id year inc80 inc81 inc82
1 1999 5000 5500 6000
2 1999 2000 2200 3300
end
reshapehelper
assert "`r(status)'" == "ok"
assert r(tested) == 1
assert strpos(`"`r(cmd)'"', "j(year)") == 0

* (e) bare stub variable v beside v1-v3 (reshape r(110) territory): composed
*     but honestly reported as blocked after the dry run cannot fix it
clear
input id v v1 v2 v3
1 9 10 11 12
2 8 20 21 22
end
reshapehelper
assert inlist("`r(status)'", "blocked", "needinfo")
assert _N == 2 & c(k) == 5

* (f) widening would build names longer than 32 chars: caution + honest fail
clear
input id year abcdefghijklmnopqrstuvwxyzabcde
1 2018 1.1
1 2019 1.2
2 2018 2.1
2 2019 2.2
end
reshapehelper, to(wide)
assert inlist("`r(status)'", "blocked", "ok")
if "`r(status)'" == "blocked" assert `"`r(caution)'"' != ""

* (g) missing values in the j candidate -> no crash, data untouched
clear
input id year x
1 2018 1
1 2019 2
1    . 3
2 2018 4
2 2019 5
end
reshapehelper, to(wide)
assert inlist("`r(status)'", "ok", "blocked", "needinfo")
assert _N == 5 & c(k) == 3

* (h) an all-missing variable beside normal stubs -> still ok
clear
input id inc80 inc81
1 5000 5500
2 2000 2200
end
gen ghost = .
reshapehelper
assert "`r(status)'" == "ok"

* (i) mixed-case stubs Inc_80/Inc_81: case preserved in the suggestion
clear
input id Inc_80 Inc_81
1 5000 5500
2 2000 2200
end
reshapehelper
assert "`r(status)'" == "ok"
assert strpos(`"`r(cmd)'"', "Inc_") > 0

* (j) value-labeled integer j -> to(wide) works
clear
input id year x
1 1 10
1 2 11
2 1 20
2 2 21
end
label define yl 1 "wave one" 2 "wave two"
label values year yl
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert r(tested) == 1

* (k) REGRESSION (adversarial finding): a chained run followed by a
*     single-step run must CLEAR the stale second-step global
clear
input famid ht_k1_t1 ht_k1_t2 ht_k2_t1 ht_k2_t2
1 3.1 3.6 4.0 4.4
2 3.3 3.8 4.1 4.6
end
reshapehelper
assert `"$reshapehelper_cmd2"' != ""
clear
input id inc80 inc81
1 5000 5500
2 2000 2200
end
reshapehelper
assert `"`r(cmd2)'"' == ""
assert `"$reshapehelper_cmd2"' == ""
* ... and a checklist run clears the first global too
sysuse auto, clear
reshapehelper
assert "`r(status)'" == "needinfo"
assert `"$reshapehelper_cmd"' == ""

* (l) varlist restriction scopes the SCAN but not the id hunt
clear
input id inc80 inc81 ue80 ue81
1 5000 5500 0 1
2 2000 2200 1 0
end
reshapehelper inc80 inc81
assert "`r(status)'" == "ok"
assert strpos(`"`r(cmd)'"', "reshape long inc, i(id)") > 0
assert strpos(`"`r(cmd)'"', "ue") == 0

* (m) user errors arrive as clean return codes
capture reshapehelper, i(no_such_var)
assert _rc == 111
capture reshapehelper, to(wide) j(no_such_var)
assert _rc == 111
clear
input id z1 z2
1 1 2
2 3 4
end
reshapehelper, to(long) stubs(qqq) i(id)
assert inlist("`r(status)'", "blocked", "needinfo")

* ---------------------------------------------------------------------------
* T22. REGRESSION (adversarial round 2): a double-quote inside a string j
*      VALUE must not crash the caller (it broke the 32-char length test)
* ---------------------------------------------------------------------------
clear
input id str8 size measure
1 "5in" 10
1 "6in" 20
2 "5in" 11
2 "6in" 21
end
replace size = subinstr(size, "in", char(34), .)   // values become  5"  6"
capture reshapehelper, to(wide) j(size)
assert _rc == 0                                     // no escaped r(132)/r(198)
assert inlist("`r(status)'", "ok", "blocked", "needinfo")
assert _N == 4 & c(k) == 3                          // data untouched
* a backtick in a j value must also be safe
clear
input id str8 code measure
1 "a" 10
1 "b" 20
2 "a" 11
2 "b" 21
end
replace code = "a" + char(96) + "b" if code == "a"
capture reshapehelper, to(wide) j(code)
assert _rc == 0
assert inlist("`r(status)'", "ok", "blocked", "needinfo")

* ---------------------------------------------------------------------------
* T23. REGRESSION: the "i() still contains the factor" note must NOT fire on a
*      terminal single-id panel (it was misreading the id as a leftover factor)
* ---------------------------------------------------------------------------
clear
input id year inc
1 80 5000
1 81 5500
2 80 2000
2 81 2200
3 80 3000
3 81 3300
end
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert strpos(`"`r(cmd)'"', "reshape wide inc, i(id) j(year)") > 0
assert `"`r(note)'"' == ""                          // no spurious factor note
* but a genuine compound-i leftover factor STILL earns the note (T14 shape)
clear
input hid str1 sex year inc
1 "f" 90 3200
1 "f" 91 4700
1 "m" 90 4500
1 "m" 91 4600
2 "f" 90 3600
2 "f" 91 3800
2 "m" 90 5100
2 "m" 91 5300
end
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert `"`r(note)'"' != ""

* ---------------------------------------------------------------------------
* T24. REGRESSION: r(direction) only ever returns a DOCUMENTED value
* ---------------------------------------------------------------------------
clear
input a b c
1 2 3
4 5 6
end
reshapehelper, to(long)
assert inlist("`r(direction)'", "wide2long", "long2wide", "doubly", "unknown")
clear
input id x y
1 1 2
2 3 4
end
reshapehelper, to(wide)
assert inlist("`r(direction)'", "wide2long", "long2wide", "doubly", "unknown")

* ---------------------------------------------------------------------------
* T25. Sparse panel: an id that DOES uniquely identify rows with year but
*      barely repeats is set aside by the plausibility bar; the checklist must
*      name it as a possible sparse-units cause and expose it in r(sparse)
* ---------------------------------------------------------------------------
clear
input id year x
1 2019 10
2 2019 20
3 2019 30
4 2019 40
5 2020 50
1 2020 11
end
reshapehelper, to(wide)
assert "`r(status)'" == "needinfo"
assert "`r(sparse)'" == "id"
assert `"`r(cmd)'"' == ""
* forcing the flagged id makes it resolve
reshapehelper, to(wide) i(id) j(year)
assert "`r(status)'" == "ok"
assert strpos(`"`r(cmd)'"', "reshape wide x, i(id) j(year)") > 0
* a normal (non-sparse) panel must NOT set r(sparse)
clear
input id year x
1 80 5
1 81 6
2 80 7
2 81 8
end
reshapehelper, to(wide)
assert "`r(status)'" == "ok"
assert "`r(sparse)'" == ""

di as res _n "test_reshapehelper.do: ALL TESTS PASSED"
