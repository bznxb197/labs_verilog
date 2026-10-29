# Запуск в ModelSim / QuestaSim: в консоли симулятора выполнить
#   do run_modelsim.do
vlib work
vlog -sv apb_master.sv apb_slave.sv tb_top.sv
vsim -voptargs=+acc work.tb_top
add wave -radix hex /tb_top/*
add wave -radix hex /tb_top/DUT/apb_st /tb_top/DUT/register_with_some_name \
                    /tb_top/DUT/reg_date /tb_top/DUT/reg_surname /tb_top/DUT/reg_name
run -all
