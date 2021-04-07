foreach sample in acs {

    local microdata_input "${input_clean_dir}clean_`sample'.dta"
    local policy_schedule_input "${input_clean_dir}modelinputs_`sample'.dta"
    local steps = 5

    mwsim run, ///
        microdata(`microdata_input') ///
        policy(`policy_schedule_input') ///
        steps(`steps') ///
        cpi("${input_clean_dir}cpi_projections_8_2020.dta") ///
        population("${input_clean_dir}pop_projections_8_2020.dta") ///
        real_wage_growth(0.005)

    save ${output_dir}model_run_microdata_`sample'.dta, replace 
}
