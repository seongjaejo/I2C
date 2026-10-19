`timescale 1ns / 1ps

module i2c_slave_board_top #(
    parameter logic [7:0] SLAVE0_ADDR_BYTE = 8'hF8,
    parameter logic [7:0] SLAVE1_ADDR_BYTE = 8'hCA,
    parameter logic [7:0] RESET_DATA0      = 8'h00,
    parameter logic [7:0] RESET_DATA1      = 8'h00
)(
    input  logic       clk,
    input  logic       rst,

    // external I2C port
    input  logic       scl,
    inout  wire        sda,

    // FND
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);

    // address byte -> 7-bit address
    // C8 = {7'h64, 1'b0}, C9 = {7'h64, 1'b1}
    // CA = {7'h65, 1'b0}, CB = {7'h65, 1'b1}
    localparam logic [6:0] SLAVE0_ADDR_7BIT = SLAVE0_ADDR_BYTE[7:1];
    localparam logic [6:0] SLAVE1_ADDR_7BIT = SLAVE1_ADDR_BYTE[7:1];

    // Shared SDA
    logic sda_i;

    logic slave0_sda_o;
    logic slave1_sda_o;

    assign sda_i = sda;

    // open-drain combine
    // 둘 중 하나라도 LOW로 당기면 SDA = 0
    assign sda = ((slave0_sda_o == 1'b0) || (slave1_sda_o == 1'b0)) ? 1'b0 : 1'bz;

    // Slave0 signals
    logic [7:0] slave0_data_reg_out;
    logic [7:0] slave0_rx_data;
    logic       slave0_selected;
    logic       slave0_rw_mode;
    logic       slave0_done;

    i2c_slave #(
        .SLAVE_ADDR (SLAVE0_ADDR_7BIT),
        .RESET_DATA (RESET_DATA0)
    ) U_I2C_SLAVE0 (
        .clk          (clk),
        .rst          (rst),

        .scl          (scl),
        .sda_i        (sda_i),
        .sda_o        (slave0_sda_o),

        .data_reg_out (slave0_data_reg_out),
        .rx_data      (slave0_rx_data),
        .selected     (slave0_selected),
        .rw_mode      (slave0_rw_mode),
        .done         (slave0_done)
    );

    // Slave1 signals
    logic [7:0] slave1_data_reg_out;
    logic [7:0] slave1_rx_data;
    logic       slave1_selected;
    logic       slave1_rw_mode;
    logic       slave1_done;

    i2c_slave #(
        .SLAVE_ADDR (SLAVE1_ADDR_7BIT),
        .RESET_DATA (RESET_DATA1)
    ) U_I2C_SLAVE1 (
        .clk          (clk),
        .rst          (rst),

        .scl          (scl),
        .sda_i        (sda_i),
        .sda_o        (slave1_sda_o),

        .data_reg_out (slave1_data_reg_out),
        .rx_data      (slave1_rx_data),
        .selected     (slave1_selected),
        .rw_mode      (slave1_rw_mode),
        .done         (slave1_done)
    );

    // Display select
    // 0: slave0 표시
    // 1: slave1 표시
    logic display_sel;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            display_sel <= 1'b0;   // 초기에는 첫 번째 slave 표시
        end else begin
            if (slave0_selected || slave0_done) begin
                display_sel <= 1'b0;
            end else if (slave1_selected || slave1_done) begin
                display_sel <= 1'b1;
            end
        end
    end

    // FND display
    // 왼쪽 2자리: 선택된 slave address byte
    // 오른쪽 2자리: 선택된 slave 내부 data_reg
    logic [7:0]  display_addr;
    logic [7:0]  display_data;
    logic [15:0] fnd_hex_value;

    always_comb begin
        if (display_sel == 1'b0) begin
            display_addr = SLAVE0_ADDR_BYTE;
            display_data = slave0_data_reg_out;
        end else begin
            display_addr = SLAVE1_ADDR_BYTE;
            display_data = slave1_data_reg_out;
        end
    end

    assign fnd_hex_value = {display_addr, display_data};

    fnd_hex_controller U_FND_HEX (
        .clk      (clk),
        .rst      (rst),
        .hex_data (fnd_hex_value),
        .fnd_com  (fnd_com),
        .fnd_data (fnd_data)
    );

endmodule