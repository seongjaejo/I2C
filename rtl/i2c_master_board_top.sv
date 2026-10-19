`timescale 1ns / 1ps

module i2c_master_board_top (
    input  logic        clk,
    input  logic        rst,

    input  logic        btn_right,
    input  logic [15:0] sw,

    output logic        scl,
    inout  wire         sda,

    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data
);

    logic [7:0] addr_byte_latched;
    logic [7:0] write_data_latched;
    logic [7:0] display_data;
    logic       rw_bit_latched;     // 0: write, 1: read

    // Button debounce
    logic btn_right_pulse;

    button_debounce U_BTN_RIGHT (
        .clk   (clk),
        .rst   (rst),
        .i_btn (btn_right),
        .o_btn (btn_right_pulse)
    );

    // I2C master core signals
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;

    logic [7:0] master_tx_data;
    logic [7:0] master_rx_data;

    logic       ack_in;
    logic       ack_out;
    logic       busy;
    logic       done;

    logic       master_sda_o;
    logic       master_sda_i;

    // SDA open-drain
    assign master_sda_i = sda;
    assign sda = (master_sda_o == 1'b0) ? 1'b0 : 1'bz;

    i2c_master U_I2C_MASTER (
        .clk       (clk),
        .rst       (rst),

        .cmd_start (cmd_start),
        .cmd_write (cmd_write),
        .cmd_read  (cmd_read),
        .cmd_stop  (cmd_stop),

        .tx_data   (master_tx_data),
        .rx_data   (master_rx_data),

        .ack_in    (ack_in),
        .ack_out   (ack_out),

        .busy      (busy),
        .done      (done),

        .scl       (scl),
        .sda_o     (master_sda_o),
        .sda_i     (master_sda_i)
    );

    // Board controller FSM
    typedef enum logic [3:0] {
        B_IDLE        = 4'd0,
        B_WAIT_START  = 4'd1,
        B_WAIT_ADDR   = 4'd2,
        B_WAIT_WDATA  = 4'd3,
        B_WAIT_READ   = 4'd4,
        B_WAIT_STOP   = 4'd5,
        B_DONE        = 4'd6
    } board_state_e;

    board_state_e board_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            board_state        <= B_IDLE;

            cmd_start          <= 1'b0;
            cmd_write          <= 1'b0;
            cmd_read           <= 1'b0;
            cmd_stop           <= 1'b0;

            master_tx_data     <= 8'h00;
            ack_in             <= 1'b1;   // read 1byte 후 NACK

            addr_byte_latched  <= 8'h00;
            write_data_latched <= 8'h00;
            display_data       <= 8'h00;
            rw_bit_latched     <= 1'b0;
        end else begin
            // command pulse default
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;

            case (board_state)

                B_IDLE: begin
                    if (btn_right_pulse) begin
                        addr_byte_latched  <= sw[15:8];
                        write_data_latched <= sw[7:0];
                        display_data       <= sw[7:0];
                        rw_bit_latched     <= sw[8];   // address byte bit0 = R/W

                        cmd_start          <= 1'b1;
                        board_state        <= B_WAIT_START;
                    end
                end

                // START 완료 후 주소 byte 먼저 전송
                B_WAIT_START: begin
                    if (done) begin
                        master_tx_data <= addr_byte_latched;
                        cmd_write      <= 1'b1;
                        board_state    <= B_WAIT_ADDR;
                    end
                end

                // 주소 byte 전송 완료 후 ACK 확인
                B_WAIT_ADDR: begin
                    if (done) begin
                        if (ack_out == 1'b1) begin
                            // 주소 NACK이면 data/read 진행하지 않고 STOP
                            cmd_stop    <= 1'b1;
                            board_state <= B_WAIT_STOP;
                        end else begin
                            if (rw_bit_latched == 1'b0) begin
                                // WRITE
                                master_tx_data <= write_data_latched;
                                cmd_write      <= 1'b1;
                                board_state    <= B_WAIT_WDATA;
                            end else begin
                                // READ 1 byte
                                ack_in      <= 1'b1;   // 마지막 byte라 NACK
                                cmd_read    <= 1'b1;
                                board_state <= B_WAIT_READ;
                            end
                        end
                    end
                end

                // write data 전송 완료
                B_WAIT_WDATA: begin
                    if (done) begin
                        display_data <= write_data_latched;

                        cmd_stop    <= 1'b1;
                        board_state <= B_WAIT_STOP;
                    end
                end

                // read data 수신 완료
                B_WAIT_READ: begin
                    if (done) begin
                        display_data <= master_rx_data;

                        cmd_stop    <= 1'b1;
                        board_state <= B_WAIT_STOP;
                    end
                end

                // STOP 완료
                B_WAIT_STOP: begin
                    if (done) begin
                        board_state <= B_DONE;
                    end
                end

                // 결과 유지 상태
                // 버튼 다시 누르면 현재 스위치 값으로 새로운 transaction
                B_DONE: begin
                    if (btn_right_pulse) begin
                        addr_byte_latched  <= sw[15:8];
                        write_data_latched <= sw[7:0];
                        display_data       <= sw[7:0];
                        rw_bit_latched     <= sw[8];

                        cmd_start          <= 1'b1;
                        board_state        <= B_WAIT_START;
                    end
                end

                default: begin
                    board_state <= B_IDLE;
                end

            endcase
        end
    end

    // FND display
    // reset 후 0000
    // transaction 시작 후 latch된 주소 + data 표시
    // read 완료 후 주소 + read data 표시
    logic [15:0] fnd_hex_value;

    assign fnd_hex_value = {addr_byte_latched, display_data};

    fnd_hex_controller U_FND_HEX (
        .clk      (clk),
        .rst      (rst),
        .hex_data (fnd_hex_value),
        .fnd_com  (fnd_com),
        .fnd_data (fnd_data)
    );

endmodule