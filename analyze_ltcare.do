local cpi2021 = 261.18575
local cpi2025 = 284.16375

sysuse state_geocodes, clear
keep state_fips state_name
rename state_fips statefips
tempfile state_geocodes
save `state_geocodes'


use ${output_dir}model_run_microdata_acs.dta, clear
gen byte affected = direct5 == 1 | indirect5 == 1
gen byte all = 1
gen byte white = racec == 1
gen byte black = racec == 2
gen byte aapi = racec == 4
gen byte male = female == 0

/*industry indicators used during ind/occ definition tests
gen private_hh = ind == 9290
gen home_health_services = ind == 8170
gen ind_fam_services = ind == 8370
gen nursing_care = ind == 8270
gen residential_care = ind == 8290
gen emp_services = ind == 7580
gen vocational_rehab = ind == 8390
gen hr_admin = ind == 9480
*/
* lt care worker defn's
gen byte ltcare_occ = occ == 3601 | occ == 3602 | occ == 3603 /* home health aide, personal care aide, nursing assistant */
gen byte ltc1 = ltcare_occ == 1
gen byte ltc2 = ltcare_occ == 1 & (inlist(ind, 9290, 8170, 8370, 8270, 8290, 8390, 9480) == 1)
gen byte ltc3 = ltcare_occ == 1 & (inlist(ind, 9290, 8170, 8370) == 1)
gen byte ltc4 = ltcare_occ == 1 & (inlist(ind, 8270, 8290) == 1)

tempfile alldata
save `alldata'


*******************************************************************************
* Counts and group share affected
*******************************************************************************
local groups all ltc1 ltc2 ltc3 ltc4

local all_title = "All occupations"
local ltc1_title = "Nursing assistants; home health and personal care aides"
local ltc2_title = "Long-term care workers"
local ltc3_title = " ...in-home"
local ltc4_title = " ...in nursing homes and residential care facilities"

foreach x in `groups' {
    use `alldata' if `x' == 1, clear
    gcollapse (sum) _total_workforce = all _total_affected = affected (mean) _share_affected = affected [pw = perwt5]
    if "`x'" == "all" local total_affected: di _total_affected
    gen category = "``x'_title'"
    tempfile tab_`x'
    save `tab_`x''
}
clear
foreach x in `groups' {
append using `tab_`x''
}

foreach x in share_affected {
    replace _`x' = _`x' * 100
    gen `x' = string(_`x', "%3.1f") + "%"
    drop _`x'
}
foreach x in total_workforce total_affected {
    replace _`x' = _`x' / 1000
    gen `x' = string(_`x', "%8.0fc")
    drop _`x'
}

lab var category "Group"
lab var total_workforce "Total workforce (thousands)"
lab var total_affected "Total affected (thousands)"
lab var share_affected "Share of group affected"

keep category total_workforce total_affected share_affected
order category total_workforce total_affected share_affected
tempfile main_table
save `main_table'

clear
set obs 1
gen title = ""
lab var title "Long-term care workers, numbers overall and affected by RTWA"
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) replace sheet("Table 1")

use `main_table', clear
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetmodify sheet("Table 1") cell(A3)


*******************************************************************************
* demographics affected, counts and shares
*******************************************************************************
local groups all female male aapi black hispanic white
local all_title "Overall"
local female_title "Female"
local male_title "Male"
local aapi_title "AAPI"
local black_title "Black"
local hispanic_title "Hispanic"
local white_title "White"

foreach x in `groups' {
    use all affected perwt5 ltc2 `x' using `alldata' if ltc2 ==1 & `x' == 1, clear
    gcollapse (sum) total_ltcare = all total_affected = affected (mean) share_affected = affected [pw = perwt5]
    gen category = "``x'_title'"
    tempfile tab_`x'
    save `tab_`x''
}
clear

use `tab_all', clear
moreobs 2
replace category = "Gender" if _n == _N
foreach x in female male {
    append using `tab_`x''
}
moreobs 2
replace category = "Race" if _n == _N
foreach x in white black hispanic aapi {
    append using `tab_`x''
}


foreach x in total_ltcare total_affected share_affected {
    rename `x' _`x'

    if "`x'" == "total_ltcare" {
        replace _`x' = _`x' / 1000
        gen `x' = string(_`x', "%6.0fc")
    }
    if "`x'" == "total_affected" {
        replace _`x' = _`x' / 1000
        gen `x' = string(_`x', "%6.0fc")
    }

    if "`x'" == "share_affected" {
        replace _`x' = _`x' * 100
        gen `x' = string(_`x', "%3.1f") + "%"
    }

    drop _`x'
}

foreach x of varlist _all {
    replace `x' = "" if `x' == "."
    replace `x' = "" if `x' == ".%"
}

lab var category "Group"
lab var total_ltcare "Total long-term care workers (thousands)"
lab var total_affected "Number affected (thousands)"
lab var share_affected "Share affected"

keep category total_ltcare total_affected share_affected
order category total_ltcare total_affected share_affected
tempfile main_table
save `main_table'

clear
set obs 1
gen title = ""
lab var title "Numbers and shares of long-term care workers affected by RTWA in 2025"
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 2")

use `main_table', clear
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetmodify sheet("Table 2") cell(A3)



*******************************************************************************
* demographics affected, wages
*******************************************************************************
local groups all female male aapi black hispanic white
local all_title "Overall"
local female_title "Female"
local male_title "Male"
local aapi_title "AAPI"
local black_title "Black"
local hispanic_title "Hispanic"
local white_title "White"

foreach x in `groups' {
    use affected perwt5 ltc2 d_annual_inc5 d_wage5 `x' using `alldata' if affected == 1 & ltc2 ==1 & `x' == 1, clear
    gcollapse (mean) d_ann = d_annual_inc5 d_wage = d_wage5 [pw = perwt5]
    gen category = "``x'_title'"
    tempfile tab_`x'
    save `tab_`x''
}
clear

use `tab_all', clear
moreobs 2
replace category = "Gender" if _n == _N
foreach x in female male {
    append using `tab_`x''
}
moreobs 2
replace category = "Race" if _n == _N
foreach x in white black hispanic aapi {
    append using `tab_`x''
}


foreach x in d_ann d_wage {
    rename `x' _`x'
    replace _`x' = _`x' * `cpi2021' / `cpi2025'

    if "`x'" == "d_ann" {
        replace _`x' = round(_`x' / 100) * 100
        gen `x' = "$" + string(_`x', "%5.0fc")
    }
    if "`x'" == "d_wage" {
        gen `x' = "$" + string(_`x', "%3.2f")
    }

    drop _`x'
}

keep category d_wage d_ann
order category d_wage d_ann
foreach x of varlist _all {
    replace `x' = "" if `x' == "."
    replace `x' = "" if `x' == "$."
}

lab var category "Group"
lab var d_wage "Average hourly increase in $"
lab var d_ann "Annual year-round annual increase in $"

tempfile main_table
save `main_table'

clear
set obs 1
gen title = ""
lab var title "Pay increases for long-term care workers affected by RTWA in 2025"
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Table 3")

use `main_table', clear
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetmodify sheet("Table 3") cell(A3)



*******************************************************************************
* wage distribution
*******************************************************************************
use `alldata' if ltc2 == 1, clear
gquantiles rtwa_wage = hrwage5 [pw=perwt5], pctile nquantiles(10) genp(percentile)
gquantiles cf_wage = cf_hrwage5 [pw=perwt5], pctile nquantiles(10) genp(percentile2)

keep percentile rtwa_wage cf_wage
keep if percentile != .
gen pct_diff = rtwa_wage / cf_wage - 1
foreach x in rtwa_wage cf_wage pct_diff {
    rename `x' _`x'

    if "`x'" == "rtwa_wage" | "`x'" == "cf_wage" {
        gen `x' = "$" + string(_`x', "%4.2f")
    }
    if "`x'" == "pct_diff" {
        replace _`x' = _`x' * 100
        gen `x' = string(_`x', "%3.1f") + "%"
    }

    if "`x'" == "share_affected" {
        replace _`x' = _`x' * 100
    }

    drop _`x'
}
drop pct_diff

lab var cf_wage "Wage in 2025 without RTWA"
lab var rtwa_wage "Wage in 2025 with RTWA"
lab var percentile "Percentile"
order percentile cf_wage rtwa_wage
tempfile main_table
save `main_table'

clear
set obs 1
gen title = ""
lab var title "Wage distribution of long-term care workers, by percentile"
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Figure A")

use `main_table', clear
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetmodify sheet("Figure A") cell(A3)




*******************************************************************************
* State-specific
*******************************************************************************
use `alldata' if ltc2 == 1, clear
gcollapse (rawsum) _total_sample = all (sum) _total_workforce = all _total_affected = affected (mean) _share_affected = affected [pw = perwt5]
tempfile tab5_us
save `tab5_us'

use `alldata' if ltc2 == 1, clear
gcollapse (rawsum) _total_sample = all (sum) _total_workforce = all _total_affected = affected (mean) _share_affected = affected [pw = perwt5], by(statefips)

append using `tab5_us'

replace _share_affected = . if _total_sample < 500 | _total_affected < 1000
replace _share_affected = _share_affected * 100
gen share_affected = string(_share_affected, "%3.1f") + "%"

replace _total_workforce = . if _total_sample < 500
gen total_workforce = string(round(_total_workforce, 1000), "%10.0fc")

replace _total_affected = . if _total_sample < 500 | _total_affected < 1000
gen total_affected = string(round(_total_affected, 1000), "%10.0fc")

foreach x in total_workforce total_affected share_affected {
    replace `x' = "NA" if `x' == "." | `x' == ".%"
}

drop _share_affected _total_workforce _total_affected _total_sample

merge 1:1 statefips using `state_geocodes'
rename state_name state
replace state = "US total" if statefips == .
drop _merge statefips

lab var total_workforce "Total long-term care workforce"
lab var total_affected "Total number of affected long-term care workers"
lab var share_affected "Share of long-term care workers affected"
label var state "State of residence"

order state total_workforce total_affected share_affected
export excel using ${output_dir}longterm_care_tables.xlsx, firstrow(varlabels) sheetreplace sheet("Figure B")
