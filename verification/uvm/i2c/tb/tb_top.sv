import uvm_pkg::*;
import i2c_pkg::*;

module tb_top ();

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    i2c_if i_if(.clk(clk));

    logic scl_line_unused;
    logic sda_line_unused;

    i2c_top dut (
        .clk            (i_if.clk),
        .rst            (i_if.reset),
        .cmd_start      (i_if.cmd_start),
        .cmd_write      (i_if.cmd_write),
        .cmd_read       (i_if.cmd_read),
        .cmd_stop       (i_if.cmd_stop),
        .tx_data        (i_if.tx_data),
        .ack_in         (i_if.ack_in),
        .master_rx_data (i_if.rx_data),
        .ack_out        (i_if.ack_out),
        .busy           (i_if.busy),
        .done           (i_if.done),
        .scl_line       (scl_line_unused),
        .sda_line       (sda_line_unused),
        .slave_data_reg (i_if.slave_data_reg),
        .slave_rx_data  (i_if.slave_rx_data),
        .slave_selected (i_if.slave_selected),
        .slave_done     (i_if.slave_done)
    );

    initial begin
        uvm_config_db #(virtual i2c_if)::set(null, "*", "i_if", i_if);
        run_test();
    end

    initial begin
        $fsdbDumpfile("i2c_tb.fsdb");
        $fsdbDumpvars(0);
    end

endmodule
