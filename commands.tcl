write_cfgmem -force -format MCS -size 16 -loaddata "up 0x0 add.dat" program.mcs
write_cfgmem  -format mcs -size 16 -interface SPIx1 -loadbit "up 0x00000000 ./impl_axi_fpga.bit " -loaddata "up 0x00800000 ./add.dat " -force -file "./program.mcs"
write_cfgmem  -format mcs -size 16 -interface SPIx1 -loadbit "up 0x00000000 ./mriscv_vivado.runs/impl_1/impl_axi_fpga.bit " -loaddata "up 0x00800000 ./add.dat " -force -file "./program.mcs"
riscv32-unknown-elf-gcc -c add.S
riscv32-unknown-elf-gcc -Os -ffreestanding -nostdlib -o add.elf -Wl,-Bstatic,-T,mriscv_fpga.ld,-Map,mriscv_fpga.map,--strip-debug add.o -lgcc
riscv32-unknown-elf-objcopy -O binary add.elf add.dat
