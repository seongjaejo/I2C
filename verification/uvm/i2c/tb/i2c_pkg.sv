package i2c_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    // 의존성 순서대로 include
    `include "i2c_seq_item.sv"
    `include "i2c_sequence.sv"
    `include "i2c_driver.sv"
    `include "i2c_monitor.sv"
    `include "i2c_agent.sv"
    `include "i2c_scoreboard.sv"
    `include "i2c_coverage.sv"
    `include "i2c_env.sv"
    `include "i2c_test.sv"
endpackage
