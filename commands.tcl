write_cfgmem -force -format MCS -size 16 -loaddata "up 0x0 add.dat" program.mcs
write_cfgmem  -format mcs -size 16 -interface SPIx1 -loadbit "up 0x00000000 ./mriscv_vivado.runs/impl_1/impl_axi.bit " -loaddata "up 0x00800000 ./ddr2.dat " -force -file "./program.mcs"
riscv32-unknown-elf-gcc -c add.S
riscv32-unknown-elf-objcopy -O binary add.o add.dat