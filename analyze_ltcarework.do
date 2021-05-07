local cpi2021 = 261.18575
local cpi2025 = 284.16375

use ${output_dir}model_run_microdata_acs.dta, clear
gen overall = 1
gen affected = direct5 == 1 | indirect5 == 1
gen all = 1
gen borh = racec == 2 | racec == 3
gen in_poverty = poverty <= 100
gen above25 = age >= 25

recode parent (. = 0)

gen home_health_aide = occ == 3601
gen personal_care_aide = occ == 3602
gen nursing_asst = occ == 3603

*industry indicators used during ind/occ definition tests
gen private_hh = ind == 9290
gen home_health_services = ind == 8170
gen ind_fam_services = ind == 8370
gen emp_services = ind == 7580
gen nursing_care = ind == 8270
gen residential_care = ind == 8290

gen homecare_orig = home_health_aide == 1 | personal_care_aide == 1
gen homecare_all = home_health_aide == 1 | personal_care_aide == 1  | nursing_asst == 1
gen homecare_home = home_health_aide == 1 | (personal_care_aide == 1 & inlist(ind, 9290, 8170, 8370, 7580) == 1)
gen homecare_all_ind = (home_health_aide == 1 | personal_care_aide == 1  | nursing_asst == 1) & (inlist(ind, 9290, 8170, 8370, 7580, 8270, 8290) == 1)

tempfile alldata
save `alldata'

local groups all homecare_orig homecare_all homecare_all_ind

local all_title = "All occupations"
local homecare_orig_title =  "Personal care and home health aides"
local homecare_all_title =  "Personal care and home health aides; Nursing assistants"
local homecare_all_ind_title =  "Personal care and home health aides; Nursing assistants (industry restriction)"

*******************************************************************************
* Counts and group share affected
*******************************************************************************
foreach x in `groups' {
    use `alldata' if `x' == 1, clear
    gcollapse (rawsum) _sample = overall (sum) _total_workforce = overall _total_affected = affected (mean) _share_affected = affected [pw = perwt5]
    if "`x'" == "all" local total_affected: di _total_affected
    gen category = "``x'_title'"
    tempfile tab1_`x'
    save `tab1_`x''
}
clear
foreach x in `groups' {
append using `tab1_`x''
}

foreach x in share_affected {
    replace _`x' = _`x' * 100
    gen `x' = string(_`x', "%3.1f") + "%"
    drop _`x'
}
foreach x in total_workforce total_affected {
    replace _`x' = _`x' / 10^6
    gen `x' = string(_`x', "%3.1f")
    drop _`x'
}
foreach x in sample {
    gen `x' = string(_`x', "%10.0fc")
    drop _`x'
}

lab var category "Group"
lab var sample "sample"
lab var total_workforce "Total workforce (millions)"
lab var total_affected "Total affected (millions)"
lab var share_affected "Share of group affected"

keep category sample total_workforce total_affected share_affected
order category sample total_workforce total_affected share_affected
export excel using ${output_dir}lt_care_workers_tables.xlsx, firstrow(varlabels) replace sheet("Table 1")

****************
* IND/OCC TEST *
****************
/*
* adding in detailed ind/occ locals
local home_health_aide_title = "Home health aides"
local personal_care_aide_title = "Personal care aides"
local nursing_asst_title = "Nursing assistants"
*local psych_aide_title = "Orderlies and Psychiatric Aides"
local private_hh_title = "Private households"
local home_health_services_title = "Home health care services"
local ind_fam_services_title = "Individual and family services"
local emp_services_title = "Employment services"
local nursing_care_title = "Nursing care facilities"
local residential_care_title = "Residential care facilities, without nursing"

local occ_groups home_health_aide personal_care_aide nursing_asst /*psych_aide*/
local ind_groups private_hh home_health_services ind_fam_services emp_services nursing_care residential_care

/* detailed industry shares of the workforce */
foreach x in `occ_groups' {
	use `alldata', clear
	keep if `x' == 1
  gen _ind = ind
  dummieslab _ind
	gcollapse (mean) _ind_* [pw=perwt5]
	gen order = 1
	reshape long _ind_, i(order) j(industry)
	drop order
	rename _ind_ `x'
  label var `x' "``x'_title'"
	tempfile part`x'
	save `part`x''
}

foreach x in `occ_groups'{
	merge m:1 industry using `part`x''
	drop _merge
}
do /projects/jwolfe/workerprofiles/code/industry_labels.do
lab val industry ind17
order industry
export excel using ${output_dir}lt_care_workers_tables.xlsx, sheet("detailed_ind_shares") sheetreplace firstrow(var)

/* detailed occupation shares of the workforce */
foreach x in `ind_groups' {
	use `alldata', clear
	keep if `x' == 1
  gen _occ = occ
  dummieslab _occ
	gcollapse (mean) _occ_* [pw=perwt5]
	gen order = 1
	reshape long _occ_, i(order) j(occupation)
	drop order
	rename _occ_ `x'
  label var `x' "``x'_title'"
	tempfile part`x'
	save `part`x''
}

foreach x in `ind_groups'{
	merge m:1 occupation using `part`x''
	drop _merge
}
do /projects/jwolfe/workerprofiles/code/occupation_labels.do
lab val occupation occ18
order occupation
export excel using ${output_dir}lt_care_workers_tables.xlsx, sheet("detailed_occ_shares") sheetreplace firstrow(var)
