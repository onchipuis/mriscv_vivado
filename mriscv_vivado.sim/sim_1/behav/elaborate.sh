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
ExecStep $xv_path/bin/xelab -wto 6c86aaafb83c4e45a8fc1dd10fd68c91 -m64 --debug typical --relax --mt 8 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot axi4_interconnect_tb_behav xil_defaultlib.axi4_interconnect_tb xil_defaultlib.glbl -log elaborate.log
