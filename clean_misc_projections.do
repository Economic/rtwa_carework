* CPI projections
import delimited using "${input_raw_dir}CPI_projections_8_2020.csv", clear 
label var quarter "Calendar quarter"
drop yearmonth
gen mdate = ym(year,month)
format %tm mdate
keep mdate quarter cpi_u
drop if cpi_u == .
save "${input_clean_dir}cpi_projections_8_2020.dta", replace

* population projections
import delimited using "${input_raw_dir}pop_projections_8_2020.csv", clear
label variable growthann "Annual growth rate"
save "${input_clean_dir}pop_projections_8_2020.dta", replace

* nominal wage growth projections in pre-treatment period
load_epiextracts, begin(2015m1) end(2019m12) sample(org) keep(year statefips wageotc orgwgt)
preserve
binipolate wageotc if wageotc > 0 [pw=orgwgt], by(statefips year) binsize(0.2) p(20) collapsefun(gcollapse)
drop percentile
rename wageotc_binned wageotc_p20
tempfile statep20 
save `statep20'
restore 
merge m:1 statefips year using `statep20', assert(3) nogenerate 
gen under20 = wageotc <= wageotc_p20
gcollapse (mean) wageotc [pw=orgwgt] if under20 == 1, by(statefips year)
keep if year == 2015 | year == 2019 
reshape wide wageotc, i(statefips) j(year) 
gen nom_wage_growth0 = (wageotc2019 / wageotc2015)^(1/5) - 1
rename statefips pwstate
keep pwstate nom_wage_growth0
save "${input_clean_dir}wage_growth_projections_bottom20.dta", replace
