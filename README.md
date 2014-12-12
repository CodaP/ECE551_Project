ECE551_Project
==============

Group Project for ECE 551

To make a regression test:
1. List your commands in uart_commands.txt // each line is a 3-byte command, a space, and a 1-byte delay
2. Simulate DSO_dig_tb   // writes to uart_data.txt
3. python plot_dumps.py  // creates graphs from uart_data.txt
4. eog *.png             // inspect the graphs
5. If the graphs are incorrect, debug and fix your uart_commands/verilog, then goto 1
6. Once the graphs are correct, save uart_data.txt to uart_data_gold.txt

To check against your regression test:
1. Simulate DSO_dig_tb
2. diff uart_data.txt uart_data_gold.txt

Other Notes:
For compiling, the scripts compile.sh and compile_ultra.sh exist for each of use.
Each simply starts design_vision with the appropriate synthesis script
(synthesis.dc, synthesis_ultra.dc)
They output the synthesized files into synth/ and synth_ultra/ respectively.
