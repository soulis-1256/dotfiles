#!/bin/bash

#Compile design files.
function compile_design {
  if [[ $file == *tb* ]]
  then
    tb_file="$file"
  fi
  ghdl -a $file
}

#Compile and elaborate the testbench
function compile_elaborate_tb {
  tb_entity=$(grep -i "entity.*tb" $tb_file | awk '{print $2}')
  ghdl -e $tb_entity
  ghdl -r $tb_entity --vcd=$tb_entity.vcd
}

if [[ $# -ne 0 ]]
then
  #delete everything but the .vhd files
  if [[ $1 == "delete" ]]
  then
    rm "$(pwd)"/{*.o,*.cf,*.vcd}
    find . -type f -name '*tb*' ! -name '*.*' -delete
    exit 1256
  fi

  for file in "$@"
  do
    compile_design $file
  done

  if [[ -n $tb_file ]]
  then
    compile_elaborate_tb $tb_file
  fi

else
  for file in *.vhd
  do
    compile_design $file
  done

  if [[ -n $tb_file ]]
  then
    compile_elaborate_tb $tb_file
  fi
fi

if [[ -n $tb_entity ]]
then
  gtkwave $tb_entity.vcd -S /usr/bin/gtkwave-sim.tcl
fi

exit 0
