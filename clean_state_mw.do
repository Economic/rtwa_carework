*input state minimum wage and tipped minimum wage values for all months
*from excel-generated csv file.
*See r:/The Data/Min Wage/Historical and projected State Minimum Wages MASTER.xlsx
*12/27/2018

import delimited using ${input_raw_dir}stmins_current.csv, clear

label variable stmin "State minimum wage"
label variable tipmin "State tipped minimum wage"

rename state statecensus

gen mdate = ym(year,month)
format %tm mdate

label variable mdate "Month and Year"
label variable pwstate "State FIPS code"
label variable statecensus "State Census code"

save ${input_clean_dir}state_mins.dta, replace
