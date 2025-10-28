if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name typical_library_set\
   -timing\
    [list ${::IMEX::libVar}/mmmc/scadv10_cln65gp_hvt_tt_1p0v_25c.lib\
    ${::IMEX::libVar}/mmmc/rom_hvt_pg_nldm_tt_1p00v_1p00v_25c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p16k_hvt_pg_nldm_tt_1p00v_1p00v_25c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p8k_hvt_pg_nldm_tt_1p00v_1p00v_25c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p1k_hvt_pg_nldm_tt_1p00v_1p00v_25c_syn.lib]
create_library_set -name max_library_set\
   -timing\
    [list ${::IMEX::libVar}/mmmc/scadv10_cln65gp_hvt_ss_0p9v_125c.lib\
    ${::IMEX::libVar}/mmmc/rom_hvt_pg_nldm_ss_0p90v_0p90v_125c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p16k_hvt_pg_nldm_ss_0p90v_0p90v_125c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p8k_hvt_pg_nldm_ss_0p90v_0p90v_125c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p1k_hvt_pg_nldm_ss_0p90v_0p90v_125c_syn.lib]
create_library_set -name min_library_set\
   -timing\
    [list ${::IMEX::libVar}/mmmc/scadv10_cln65gp_hvt_ff_1p1v_m40c.lib\
    ${::IMEX::libVar}/mmmc/rom_hvt_pg_nldm_ff_1p10v_1p10v_m40c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p16k_hvt_pg_nldm_ff_1p10v_1p10v_m40c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p8k_hvt_pg_nldm_ff_1p10v_1p10v_m40c_syn.lib\
    ${::IMEX::libVar}/mmmc/sram1p1k_hvt_pg_nldm_ff_1p10v_1p10v_m40c_syn.lib]
create_rc_corner -name best_rc_corner\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -qx_tech_file ${::IMEX::libVar}/mmmc/best_rc_corner/icecaps.tch
create_rc_corner -name worst_rc_corner\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -qx_tech_file ${::IMEX::libVar}/mmmc/best_rc_corner/icecaps.tch
create_delay_corner -name min_delay_corner\
   -library_set min_library_set\
   -rc_corner best_rc_corner
create_delay_corner -name max_delay_corner\
   -library_set max_library_set\
   -rc_corner worst_rc_corner
create_constraint_mode -name prelayout_constraint_mode\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/prelayout_constraint_mode/prelayout_constraint_mode.sdc]
create_analysis_view -name setup_analysis_view -constraint_mode prelayout_constraint_mode -delay_corner max_delay_corner -latency_file ${::IMEX::dataVar}/mmmc/views/setup_analysis_view/latency.sdc
create_analysis_view -name hold_analysis_view -constraint_mode prelayout_constraint_mode -delay_corner min_delay_corner -latency_file ${::IMEX::dataVar}/mmmc/views/hold_analysis_view/latency.sdc
set_analysis_view -setup [list setup_analysis_view] -hold [list hold_analysis_view]
