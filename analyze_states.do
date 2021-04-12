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
* Private households 9290
* Home health care services 8170
* Individual and family services 8370
* Employment services 7580 - Heidi suggested this
gen homecare_home = home_health_aide == 1 | (personal_care_aide == 1 & inlist(ind, 9290, 8170, 8370, 7580) == 1)

tempfile alldata
save `alldata'

local groups childcare homecare_all carework_all

local all_title = "All occupations"
local childcare_title = "Childcare workers"
local homecare_all_title =  "Personal care and home health aides"
local homecare_home_title = "... In home care"
local carework_all_title = "All care workers"

*******************************************************************************
* Counts and group share affected
*******************************************************************************
foreach x in `groups' {
    use `alldata' if `x' == 1, clear
    gcollapse (sum) _total_sample = overall, by(statefips)
    gen category = "`x'"
    tempfile tab1_`x'
    save `tab1_`x''
}
clear
foreach x in `groups' {
  append using `tab1_`x''
}

foreach x in total_sample {
    gen `x' = string(_`x', "%3.0f")
    drop _`x'
}

reshape wide total_sample, i(statefips) j(category) string
rename total_sample* *

foreach x in `groups' {
  label var `x' "``x'_title'"
}

merge 1:1 statefips using `state_geocodes'
assert _merge == 3
drop _merge statefips
rename state_name state

order state
export excel using ${output_dir}care_workers_state.xlsx, firstrow(varlabels) replace sheet("overall_sample")
