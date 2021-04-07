set more off
clear all

* raw model inputs
global input_raw_dir inputs_raw/
* cleaned model inputs
global input_clean_dir inputs_clean/
* model outputs
global output_dir outputs/

* clean up min wage data 
do clean_state_mw.do
do clean_substate_mw.do

* create misc data sets: population and CPI projections
do clean_misc_projections.do  
 
* create wide datasets of policy, state, and substate min wage steps
do create_policy_schedule.do
 
* clean up acs and add min wage steps
* if you make changes to the policy schedule, do re-run:
do clean_acs.do
 
do run_models.do

do analyze_carework.do