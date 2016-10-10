vlib work
vlib msim

vlib msim/xil_defaultlib
vlib msim/xpm

vmap xil_defaultlib msim/xil_defaultlib
vmap xpm msim/xpm

vlog -work xil_defaultlib -64 -sv \
"/opt/Xilinx/Vivado/2016.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -64 \
"/opt/Xilinx/Vivado/2016.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib -64 \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/clocking/mig_7series_v4_0_infrastructure.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/clocking/mig_7series_v4_0_tempmon.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/clocking/mig_7series_v4_0_clk_ibuf.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/clocking/mig_7series_v4_0_iodelay_ctrl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ip_top/mig_7series_v4_0_mem_intfc.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ip_top/mig_7series_v4_0_memc_ui_top_axi.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_4lanes.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_mc_phy_wrapper.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_data.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_meta.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_tap_base.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_dqs_found_cal_hr.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_edge_store.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_cntlr.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_mux.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_rdlvl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_init.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_top.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_prbs_rdlvl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_cc.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_lim.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_po_cntlr.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_byte_lane.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_top.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_edge.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_prbs_gen.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrcal.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrlvl_off_delay.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ck_addr_cmd_delay.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_mc_phy.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_byte_group_io.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_samp.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_if_post_fifo.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_poc_pd.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_calib_top.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrlvl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_dqs_found_cal.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_oclkdelay_cal.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_of_pre_fifo.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_tempmon.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ui/mig_7series_v4_0_ui_top.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ui/mig_7series_v4_0_ui_rd_data.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ui/mig_7series_v4_0_ui_cmd.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ui/mig_7series_v4_0_ui_wr_data.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_queue.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_col_mach.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_arb_row_col.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_rank_cntrl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_state.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_arb_mux.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_round_robin_arb.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_cntrl.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_rank_mach.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_mach.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_mc.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_common.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_rank_common.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_bank_compare.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/controller/mig_7series_v4_0_arb_select.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_and.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_fsm.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_r_channel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_ar_channel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_wr_cmd_fsm.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_axi_upsizer.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_r_upsizer.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_aw_channel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_top.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_reg.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_latch_or.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_addr_decode.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_read.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_arbiter.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_a_upsizer.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator_sel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_latch_and.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_or.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_axic_register_slice.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_reg_bank.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_simple_fifo.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_fifo.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_w_channel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_axi_register_slice.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator_sel_static.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_w_upsizer.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_ddr_command_fifo.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_incr_cmd.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_translator.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_wrap_cmd.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_write.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/axi/mig_7series_v4_0_axi_mc_b_channel.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ecc/mig_7series_v4_0_fi_xor.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ecc/mig_7series_v4_0_ecc_merge_enc.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ecc/mig_7series_v4_0_ecc_gen.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ecc/mig_7series_v4_0_ecc_buf.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ecc/mig_7series_v4_0_ecc_dec_fix.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ddr_axi_mig_sim.v" \
"../../../../mriscv_vivado.srcs/sources_1/ip/ddr_axi/ddr_axi/user_design/rtl/ddr_axi.v" \

vlog -work xil_defaultlib "glbl.v"

