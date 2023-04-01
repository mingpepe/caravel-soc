sudo apt update
sudo apt install iverilog gtkwave vim python gcc git -y
sudo wget -O /tmp/riscv32-unknown-elf.gcc-12.1.0.tar.gz https://github.com/stnolting/riscv-gcc-prebuilt/releases/download/rv32i-4.0.0/riscv32-unknown-elf.gcc-12.1.0.tar.gz
sudo mkdir /opt/riscv
sudo tar -xzf /tmp/riscv32-unknown-elf.gcc-12.1.0.tar.gz -C /opt/riscv
git clone https://github.com/bol-edu/caravel-soc
chmod +x caravel-soc/testbench/counter_la/run_sim ~/caravel-soc/testbench/counter_wb/run_sim ~/caravel-soc/testbench/gcd_la/run_sim
chmod +x caravel-soc/testbench/counter_la/run_debug ~/caravel-soc/testbench/counter_wb/run_debug ~/caravel-soc/testbench/gcd_la/run_debug
chmod +x caravel-soc/testbench/counter_la/run_clean ~/caravel-soc/testbench/counter_wb/run_clean ~/caravel-soc/testbench/gcd_la/run_clean
echo 'export PATH=$PATH:/opt/riscv/bin' >> ~/.bashrc
source ~/.bashrc

sudo apt install make g++ zlib1g-dev gdb -y
git clone https://github.com/tomverbeure/gdbwave.git
pushd gdbwave/src && make && popd
