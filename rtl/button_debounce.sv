`timescale 1ns / 1ps

module button_debounce (

    input  logic clk,
    input  logic rst,
    input  logic i_btn,
    output logic o_btn

);

    // clock divider
    // 100MHz -> 100KHz
    localparam int F_COUNT = 100_000_000/100_000;
    logic [$clog2(F_COUNT)-1:0] r_counter;
    logic clk_100khz;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
        r_counter <= 0;
        clk_100khz <= 1'b0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == F_COUNT - 1) begin
                r_counter <= 0;
                clk_100khz <= 1'b1;
            end else begin
                clk_100khz <= 1'b0;
            end
        end
    end

    // synchronizer
    logic [7:0] sync_reg;
    logic [7:0] sync_next;

    logic debounce;

    always_ff @(posedge clk_100khz or posedge rst) begin
        if (rst) begin
            sync_reg <= 8'd0;
        end else begin
            sync_reg <= sync_next;
        end
    end

    always_comb begin
        sync_next = {i_btn, sync_reg[7:1]};
        // sync_next = {sync_reg[6:0], i_btn};
    end

    // 8 input to 1 output and gate
    assign debounce = &sync_reg;

    logic edge_reg;

    // rising edge detect
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = debounce & (~edge_reg);

endmodule
