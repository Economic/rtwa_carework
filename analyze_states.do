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
use `alldata' if carework_all == 1, clear
gcollapse (rawsum) _total_sample = overall (sum) _total_workforce = overall _total_affected = affected (mean) _share_affected = affected [pw = perwt5]
tempfile tab5_us
save `tab5_us'

use `alldata' if carework_all == 1, clear
gcollapse (rawsum) _total_sample = overall (sum) _total_workforce = overall _total_affected = affected (mean) _share_affected = affected [pw = perwt5], by(statefips)

append using `tab5_us'

replace _share_affected = . if _total_sample < 1000
replace _share_affected = _share_affected * 100
gen share_affected = string(_share_affected, "%3.0f") + "%"

replace _total_workforce = . if _total_sample < 500
gen total_workforce = string(round(_total_workforce, 1000), "%10.0fc")

replace _total_affected = . if _total_sample < 1000
gen total_affected = string(round(_total_affected, 1000), "%10.0fc")

foreach x in total_workforce total_affected share_affected {
    replace `x' = "NA" if `x' == "." | `x' == ".%"
}

drop _share_affected _total_workforce _total_affected _total_sample

merge 1:1 statefips using `state_geocodes'
rename state_name state
replace state = "US total" if statefips == .
drop _merge statefips

lab var total_workforce "Total care workforce"
lab var total_affected "Total number of affected care workers"
lab var share_affected "Share of care workers affected"
label var state "State of residence"

order state total_workforce total_affected share_affected
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 5")
