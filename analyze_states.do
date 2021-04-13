local cpi2021 = 261.18575
local cpi2025 = 284.16375

sysuse state_geocodes
keep state_fips state_name
rename state_fips statefips
tempfile state_geocodes
save `state_geocodes'

use ${output_dir}model_run_microdata_acs.dta, clear
gen overall = 1
gen affected = direct5 == 1 | indirect5 == 1
gen all = 1

gen childcare = occ == 4600
gen home_health_aide = occ == 3601
gen personal_care_aide = occ == 3602
gen homecare_all = home_health_aide == 1 | personal_care_aide == 1
gen carework_all = home_health_aide == 1 | personal_care_aide == 1 | childcare == 1

tempfile alldata
save `alldata'

local groups carework_all

local all_title = "All occupations"
local childcare_title = "Childcare workers"
local homecare_all_title =  "Personal care and home health aides"
local carework_all_title = "All care workers"

*******************************************************************************
* Counts and group share affected
*******************************************************************************
foreach x in `groups' {
    use `alldata' if `x' == 1, clear
    gcollapse (rawsum) _total_sample = overall (sum) _total_workforce = overall _total_affected = affected (mean) _share_affected = affected [pw = perwt5], by(statefips)
    gen category = "`x'"
    tempfile tab1_`x'
    save `tab1_`x''
}
clear
foreach x in `groups' {
  append using `tab1_`x''
}

foreach x in share_affected {
    replace _`x' = . if _total_sample < 500
    replace _`x' = _`x' * 100
    gen `x' = string(_`x', "%3.1fc") + "%"
    replace `x' = "." if _`x' == .
    drop _`x'
}
foreach x in total_workforce total_affected {
    replace _`x' = . if _total_sample < 500
    gen `x' = string(_`x', "%3.0f")
    drop _`x'
}
drop _total_sample category

merge 1:1 statefips using `state_geocodes'
assert _merge == 3
drop _merge statefips
rename state_name state

lab var total_workforce "Total care workforce"
lab var total_affected "Total number of affected care workers"
lab var share_affected "Share of care workers affected"
label var state "State of residence"

order state total_workforce total_affected share_affected
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) replace sheet("Table 5")
