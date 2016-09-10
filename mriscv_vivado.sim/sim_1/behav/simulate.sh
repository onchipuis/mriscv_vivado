#!/bin/bash -f
xv_path="/usr/local/Xilinx/Vivado/2015.4"
ExecStep()
{
"$@"
RETVAL=$?
if [ $RETVAL -ne 0 ]
then
exit $RETVAL
fi
}
ExecStep $xv_path/bin/xsim axi4_interconnect_tb_behav -key {Behavioral:sim_1:Functional:axi4_interconnect_tb} -tclbatch axi4_interconnect_tb.tcl -log simulate.log
