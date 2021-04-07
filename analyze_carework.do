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

gen childcare = occ == 4600
gen home_health_aide = occ == 3601
gen personal_care_aide = occ == 3602
gen homecare_all = home_health_aide == 1 | personal_care_aide == 1 
* Private households 9290 
* Home health care services 8170
* Individual and family services 8370
* Employment services 7580 - Heidi suggested this
gen homecare_home = home_health_aide == 1 | (personal_care_aide == 1 & inlist(ind, 9290, 8170, 8370, 7580) == 1)  


foreach x in all female borh {
    gen `x'_dwagebill = d_annual_inc5 if `x' == 1 
}

tempfile alldata 
save `alldata' 

local groups all childcare homecare_all homecare_home

local all_title = "All occupations"
local childcare_title = "Childcare workers"
local homecare_all_title =  "Personal care and home health aides"
local homecare_home_title = "... In home care"


*******************************************************************************
* Counts and group share affected
*******************************************************************************
foreach x in `groups' {
    use `alldata' if `x' == 1, clear 
    gcollapse (sum) _total_workforce = overall _total_affected = affected (mean) _share_affected = affected [pw = perwt5]
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

lab var category "Group"
lab var total_workforce "Total workforce (millions)"
lab var total_affected "Total affected (millions)"
lab var share_affected "Share of group affected"

keep category total_workforce total_affected share_affected 
order category total_workforce total_affected share_affected
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) replace sheet("Table 1")


*******************************************************************************
* distribution affected
*******************************************************************************
local statlist female borh above25
foreach x in `groups' {
    use `alldata' if `x' == 1 & affected == 1, clear 
    gcollapse (mean) `statlist' [pw = perwt5]
    gen category = "``x'_title'"
    tempfile tab1_`x'
    save `tab1_`x''
}
clear 
foreach x in `groups' {
    append using `tab1_`x''
}
foreach x in `statlist' {
    rename `x' _`x'
    replace _`x' = _`x' * 100
    gen `x' = string(_`x', "%3.1f") + "%"
    drop _`x'
}

lab var category "Group"
lab var female "Female"
lab var borh "Black or Hispanic"
lab var above25 "Ages 25 and over"

keep category `statlist'
order category `statlist'
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 2")


*******************************************************************************
* average wage effect
*******************************************************************************
foreach x in `groups' {
    use `alldata' if `x' == 1 & affected == 1, clear
    gcollapse (mean) overall = all_dwagebill female = female_dwagebill borh = borh_dwagebill [pw = perwt5]
    gen category = "``x'_title'"
    tempfile tab3_`x'
    save `tab3_`x''
}
clear 
foreach x in `groups' {
    append using `tab3_`x''
}
foreach x in overall female borh {
    rename `x' _`x'
    replace _`x' = _`x' * `cpi2021' / `cpi2025' 
    replace _`x' = round(_`x'/100) * 100
    gen `x' = "$" + string(_`x', "%5.0fc") 
    drop _`x'
} 

lab var category "Group"
lab var overall "Overall"
lab var female "Female"
lab var borh "Black or Hispanic"

keep category overall female borh 
order category overall female borh 
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 3")


*******************************************************************************
* wage percentiles table
*******************************************************************************
local plist 10(10)90

foreach x in `groups' {
    use `alldata' if `x' == 1, clear 
    binipolate hrwage5 [pw=perwt5], binsize(0.25) p(`plist') collapsefun(gcollapse)
    tempfile wagep
    save `wagep'

    use `alldata' if `x' == 1, clear 
    binipolate cf_hrwage5 [pw=perwt5], binsize(0.25) p(`plist') collapsefun(gcollapse)
    merge 1:1 percentile using `wagep', assert(3) nogenerate

    replace cf_hrwage5_binned = cf_hrwage5_binned * `cpi2021' / `cpi2025'
    replace hrwage5_binned = hrwage5_binned * `cpi2021' / `cpi2025'

    rename cf_hrwage5_binned `x'_0
    rename hrwage5_binned `x'_1

    gen `x'_diff = `x'_1/`x'_0 - 1
    tempfile percentiles_`x'
    save `percentiles_`x''
}

local counter = 0
foreach x in `groups' {
    local counter = `counter' + 1
    if `counter' == 1 use `percentiles_`x'', clear 
    else merge 1:1 percentile using `percentiles_`x'', assert(3) nogenerate
}

foreach x in `groups' {
    foreach cat in 0 1 {
        rename `x'_`cat' _`x'_`cat'
        gen `x'_`cat' = "$" + string(_`x'_`cat', "%5.2f")
        drop _`x'_`cat'
    }
    rename `x'_diff _`x'_diff
    gen `x'_diff = string(_`x'_diff * 100, "%3.1f") + "%"
    drop _`x'_`cat'
}

rename percentile _percentile
gen percentile = string(_percentile) + "th"
drop _percentile
lab var percentile "Percentile"

foreach var of varlist *_0 {
    lab var `var' "Without RTWA"
}

foreach var of varlist *_1 {
    lab var `var' "With RTWA"
}

foreach var of varlist *_diff {
    lab var `var' "Percent difference"
 
}
lab var percentile "Percentile"
local order percentile childcare_0 childcare_1 childcare_diff homecare_all_0 homecare_all_1 homecare_all_diff homecare_home_0 homecare_home_1 homecare_home_diff
order `order'
keep `order'
tempfile percentiles
save `percentiles'

* Create Table headers
clear 
set obs 1
forvalues i = 1 / 8 {
    gen blank`i' = ""
}
lab var blank1 " "
lab var blank2 "`childcare_title'"
lab var blank3 " "
lab var blank4 " "
lab var blank5 "`homecare_all_title'"
lab var blank6 " "
lab var blank7 " "
lab var blank8 "`homecare_home_title'"
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 4")

use `percentiles', clear
export excel using ${output_dir}care_workers_tables.xlsx, firstrow(varlabels) sheetmodify sheet("Table 4") cell("A2")
