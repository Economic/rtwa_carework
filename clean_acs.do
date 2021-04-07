* grab division codes
sysuse state_geocodes.dta, clear
rename state_fips statefips 
keep statefips division
tempfile division_codes 
save `division_codes'

* clean ACS data
use /data/acs/acs_state.dta, clear

keep if pwstate > 0
drop perwt0 perwt1 hrwage0 hrwage1 met2013 nfams subfam foodstmp racamind racblk ///
  racasian racpacis racwht racother racnum empstat ind1990 classwkr adj_wkswork*

rename hrwage2 hrwage0
label var hrwage0 "Hourly wage at data period"

rename perwt2 perwt0
label var perwt0 "Raked person weight at data period"

replace ftotinc = . if ftotinc>=9999999
replace ftotinc = 0 if ftotinc<0
replace hhincome = . if hhincome>=9999999
replace inctot = . if inctot>=9999999
replace incwage = . if incwage>=9999999

*sex
gen byte female = .
replace female = 1 if sex==2
replace female = 0 if sex==1

lab var female "Female"
#delimit ;
lab define female
0 "Male"
1 "Female"
;
#delimit cr
lab val female female
drop sex

*race/ethnicity
gen byte racec = .
replace racec = 1 if (hispan==0 & race==1) 
replace racec = 2 if (hispan==0 & race==2)
replace racec = 3 if (1<=hispan & hispan <=4)
replace racec = 4 if (hispan==0 & (4<=race & race <=6))
replace racec = 5 if (hispan==0 & (race==3 | race>6))

lab var racec "Race / ethnicity"
#delimit ;
lab define racec
1 "White, non-Hispanic" 
2 "Black, non-Hispanic" 
3 "Hispanic, any race" 
4 "Asian, non-Hispanic" 
5 "Other race/ethnicity"
;
#delimit cr

label val racec racec
drop race raced hispan hispand

*education
gen byte edc = .
replace edc=1 if 2<=educd & educd < 62
replace edc=2 if 62<=educd & educd<=64
replace edc=3 if 65<=educd & educd<=71
replace edc=4 if 81<=educd & educd<=83
replace edc=5 if 101<=educd & educd<=. 

label var edc "Educational attainment"

#delimit ;
label define edc 
1 "Less than high school" 
2 "High school"
3 "Some college, no degree"
4 "Associates degree"
5 "Bachelors degree or higher" 
; 

#delimit cr
label val edc edc
drop educ educd

*Marital and parental status
gen byte parent=.
replace parent=1 if (nchild>=1 & hasyouth_fam==1)
label var parent "Parent flag"

gen byte childc=.
replace childc = 1 if (parent==1 & (1<=marst & marst<=2))
replace childc = 2 if (parent==1 & marst>2)
replace childc = 3 if (parent~=1 & (1<=marst & marst<=2))
replace childc = 4 if (parent~=1 & marst>2)

lab var childc "Family status"
#delimit ;
lab define childc
1 "Married parent"
2 "Single parent"
3 "Married, no children"
4 "Unmarried, no children"
;
#delimit cr
lab val childc childc
drop marst

*define worker-specific categories
gen byte worker = 0
replace worker = 1 if age >= 16 & hrwage0 > 0 & hrwage0 != . & (22 <= classwkrd & classwkrd <= 28) & (10 <=empstatd & empstatd <= 12)
drop if worker == 0
lab var worker "Wage-earning worker status"
lab define l_worker 0 "Not a wage-earner" 1 "Wage-earner"
label values worker l_worker

*sector
gen byte sectc=.
replace sectc = 1 if classwkrd==22
replace sectc = 2 if classwkrd==23
replace sectc = 3 if (24<=classwkrd & classwkrd<=28)
replace sectc = 4 if (10<=classwkrd & classwkrd <20)

lab var sectc "Sector"
#delimit ;
lab define sectc
1 "For profit"
2 "Nonprofit"
3 "Government"
4 "Self-employed"
;
#delimit cr
lab val sectc sectc

*Tipped workers
gen byte tipc = .
replace tipc = 0 if worker == 1
replace tipc = 1 if (worker == 1 & inlist(occ,4120,4130) & inlist(ind,8580,8590,8660,8670,8680,8690,8970,8980,8990,9090))
* pre socc18
replace tipc = 1 if (worker == 1 & inlist(occ,4040,4060,4110,4400,4500,4510,4520))
* with socc18
replace tipc = 1 if (worker == 1 & inlist(occ,4040,4110,4400,4500,4510,4521,4522,4525))

lab var tipc "Tipped occupations"
lab define tipc 0 "Not tipped" 1 "Tipped worker" 
lab val tipc tipc

*PW State
lab var pwstate "Place of work state"
lab val pwstate STATEFIP

lab var pwpuma "Place of work PUMA"

tempfile basedata 
save `basedata' 

foreach sample in acs {
  * determine number of step increases, useful later
  use ${input_clean_dir}modelinputs_`sample', clear 
  sum step 
  local steps = r(max)

  use `basedata', clear 

  *merge in existing and scheduled state minimum wages
  merge m:1 pwstate using "${input_clean_dir}active_state_mins_`sample'.dta", assert(3) nogenerate

  *merge in existing and scheduled local minimum wages
  merge m:1 pwstate pwpuma using "${input_clean_dir}active_local_mins_`sample'.dta", assert(1 3)
  drop _merge

  *replace binding current law minimum wage with local min where appropriate 
  forvalues a = 1/`steps' {
    replace stmin`a' = local_mw`a' if local_mw`a' > stmin`a' & local_mw`a' != .
    replace tipmin`a' = local_tw`a' if local_tw`a' > tipmin`a' & local_tw`a' != .
  }
  drop local_mw* local_tw*

  * merge counterfactual wage growth projections
  merge m:1 pwstate using "${input_clean_dir}wage_growth_projections_bottom20.dta", assert(3) nogenerate

  compress 
  save "${input_clean_dir}clean_`sample'.dta", replace
}


