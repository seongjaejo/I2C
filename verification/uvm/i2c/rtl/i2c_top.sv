`timescale 1ns / 1ps

module i2c_top (
    input  logic       clk,
    input  logic       rst,

    // master command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,

    input  logic [7:0] tx_data,
    input  logic       ack_in,

    output logic [7:0] master_rx_data,
    output logic       ack_out,
    output logic       busy,
    output logic       done,

    // waveform check
    output logic       scl_line,
    output logic       sda_line,

    // slave debug
    output logic [7:0] slave_data_reg,
    output logic [7:0] slave_rx_data,
    output logic       slave_selected,
    output logic       slave_done
);

    logic master_sda_o;
    logic master_sda_i;

    logic slave_sda_o;
    logic slave_sda_i;

    logic scl_bus;

    // simulation용 I2C SDA bus
    // tri1은 아무도 LOW로 안 당기면 기본 HIGH가 됨
    tri1 sda_bus;

    assign sda_bus = (master_sda_o == 1'b0) ? 1'b0 : 1'bz;
    assign sda_bus = (slave_sda_o  == 1'b0) ? 1'b0 : 1'bz;

    assign master_sda_i = sda_bus;
    assign slave_sda_i  = sda_bus;

    assign scl_line = scl_bus;
    assign sda_line = sda_bus;

    i2c_master U_I2C_MASTER (
        .clk       (clk),
        .rst       (rst),

        .cmd_start (cmd_start),
        .cmd_write (cmd_write),
        .cmd_read  (cmd_read),
        .cmd_stop  (cmd_stop),

        .tx_data   (tx_data),
        .rx_data   (master_rx_data),

        .ack_in    (ack_in),
        .ack_out   (ack_out),

        .busy      (busy),
        .done      (done),

        .scl       (scl_bus),
        .sda_o     (master_sda_o),
        .sda_i     (master_sda_i)
    );

    i2c_slave #(
        .SLAVE_ADDR (7'h27),
        .RESET_DATA (8'hA5)
    ) U_I2C_SLAVE (
        .clk          (clk),
        .rst          (rst),

        .scl          (scl_bus),
        .sda_i        (slave_sda_i),
        .sda_o        (slave_sda_o),

        .data_reg_out (slave_data_reg),
        .rx_data      (slave_rx_data),
        .selected     (slave_selected),
        .rw_mode      (),
        .done         (slave_done)
    );

endmodule
