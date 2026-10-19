`timescale 1ns / 1ps

module fnd_hex_controller (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] hex_data,
    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data
);

    logic [16:0] refresh_cnt;
    logic [1:0]  digit_sel;
    logic [3:0]  hex_digit;

    // 100MHz 기준 약 1kHz 정도로 digit scan
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_cnt <= 17'd0;
            digit_sel   <= 2'd0;
        end else begin
            if (refresh_cnt == 100_000 - 1) begin
                refresh_cnt <= 17'd0;
                digit_sel   <= digit_sel + 1'b1;
            end else begin
                refresh_cnt <= refresh_cnt + 1'b1;
            end
        end
    end

    always_comb begin
        case (digit_sel)
            2'd0: begin
                fnd_com   = 4'b1110;
                hex_digit = hex_data[3:0];
            end
            2'd1: begin
                fnd_com   = 4'b1101;
                hex_digit = hex_data[7:4];
            end
            2'd2: begin
                fnd_com   = 4'b1011;
                hex_digit = hex_data[11:8];
            end
            2'd3: begin
                fnd_com   = 4'b0111;
                hex_digit = hex_data[15:12];
            end
            default: begin
                fnd_com   = 4'b1111;
                hex_digit = 4'h0;
            end
        endcase
    end

    always_comb begin
        case (hex_digit)
            4'h0: fnd_data = 8'hc0;
            4'h1: fnd_data = 8'hf9;
            4'h2: fnd_data = 8'ha4;
            4'h3: fnd_data = 8'hb0;
            4'h4: fnd_data = 8'h99;
            4'h5: fnd_data = 8'h92;
            4'h6: fnd_data = 8'h82;
            4'h7: fnd_data = 8'hf8;
            4'h8: fnd_data = 8'h80;
            4'h9: fnd_data = 8'h90;
            4'ha: fnd_data = 8'h88;
            4'hb: fnd_data = 8'h83;
            4'hc: fnd_data = 8'hc6;
            4'hd: fnd_data = 8'ha1;
            4'he: fnd_data = 8'h86;
            4'hf: fnd_data = 8'h8e;
            default: fnd_data = 8'hff;
        endcase
    end

endmodule
