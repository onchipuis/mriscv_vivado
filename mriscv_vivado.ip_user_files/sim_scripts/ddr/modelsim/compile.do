vlib work
vlib msim

vlib msim/xil_defaultlib

vmap xil_defaultlib msim/xil_defaultlib

vlog -work xil_defaultlib -64 -incr \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ecc/mig_7series_v2_4_fi_xor.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ecc/mig_7series_v2_4_ecc_dec_fix.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ecc/mig_7series_v2_4_ecc_merge_enc.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ecc/mig_7series_v2_4_ecc_gen.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ecc/mig_7series_v2_4_ecc_buf.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_edge.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_wrcal.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_mux.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_tempmon.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_wrlvl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_tap_base.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_top.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_wrlvl_off_delay.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_meta.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_of_pre_fifo.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_top.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_if_post_fifo.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_prbs_rdlvl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ck_addr_cmd_delay.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_cc.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_dqs_found_cal_hr.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_mc_phy_wrapper.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_oclkdelay_cal.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_po_cntlr.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_edge_store.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_calib_top.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_byte_lane.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_4lanes.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_data.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_poc_pd.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_mc_phy.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_cntlr.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_lim.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_ocd_samp.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_rdlvl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_byte_group_io.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_prbs_gen.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_init.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/phy/mig_7series_v2_4_ddr_phy_dqs_found_cal.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ip_top/mig_7series_v2_4_mem_intfc.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ip_top/mig_7series_v2_4_memc_ui_top_std.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_col_mach.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_queue.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_rank_common.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_round_robin_arb.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_rank_cntrl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_common.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_state.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_mc.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_cntrl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_mach.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_arb_row_col.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_rank_mach.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_arb_mux.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_bank_compare.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/controller/mig_7series_v2_4_arb_select.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ui/mig_7series_v2_4_ui_wr_data.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ui/mig_7series_v2_4_ui_cmd.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ui/mig_7series_v2_4_ui_top.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ui/mig_7series_v2_4_ui_rd_data.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/clocking/mig_7series_v2_4_infrastructure.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/clocking/mig_7series_v2_4_clk_ibuf.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/clocking/mig_7series_v2_4_tempmon.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/clocking/mig_7series_v2_4_iodelay_ctrl.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ddr_mig_sim.v" \
"../../../../picorv32_vivado.srcs/sources_1/ip/ddr/ddr/user_design/rtl/ddr.v" \


vlog -work xil_defaultlib "glbl.v"

