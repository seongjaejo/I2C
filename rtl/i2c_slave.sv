`timescale 1ns / 1ps

module i2c_slave #(
    parameter logic [6:0] SLAVE_ADDR = 7'h27,
    parameter logic [7:0] RESET_DATA = 8'hA5
)(
    input  logic       clk,
    input  logic       rst,

    // external i2c port
    input  logic       scl,
    input  logic       sda_i,
    output logic       sda_o,

    // debug / internal check
    output logic [7:0] data_reg_out,   // slave 내부 저장값
    output logic [7:0] rx_data,        // master가 write한 최근 data
    output logic       selected,       // 주소 match 여부
    output logic       rw_mode,        // 0: write, 1: read
    output logic       done            // data 1byte 수신 완료 pulse
);

    typedef enum logic [3:0] {
        S_IDLE       = 4'd0,
        S_ADDR       = 4'd1,
        S_ACK_ADDR   = 4'd2,
        S_RX_DATA    = 4'd3,
        S_ACK_RX     = 4'd4,
        S_TX_DATA    = 4'd5,
        S_RX_MACK    = 4'd6,
        S_IGNORE     = 4'd7
    } slave_state_e;

    slave_state_e state;

    logic scl_sync1, scl_sync2, scl_prev;
    logic sda_sync1, sda_sync2, sda_prev;

    logic scl_posedge;
    logic scl_negedge;
    logic start_cond;
    logic stop_cond;

    logic [7:0] shift_reg;
    logic [7:0] data_reg;
    logic [7:0] tx_shift_reg;
    logic [2:0] bit_cnt;

    logic ack_phase;
    logic master_ack;

    logic [7:0] shift_next;

    assign data_reg_out = data_reg;

    assign scl_posedge = (~scl_prev) & scl_sync2;
    assign scl_negedge = scl_prev & (~scl_sync2);

    assign start_cond  = scl_sync2 & sda_prev & (~sda_sync2);
    assign stop_cond   = scl_sync2 & (~sda_prev) & sda_sync2;

    assign shift_next  = {shift_reg[6:0], sda_sync2};

    // SCL, SDA 동기화 + edge detect
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_sync1 <= 1'b1;
            scl_sync2 <= 1'b1;
            scl_prev  <= 1'b1;

            sda_sync1 <= 1'b1;
            sda_sync2 <= 1'b1;
            sda_prev  <= 1'b1;
        end else begin
            scl_sync1 <= scl;
            scl_sync2 <= scl_sync1;
            scl_prev  <= scl_sync2;

            sda_sync1 <= sda_i;
            sda_sync2 <= sda_sync1;
            sda_prev  <= sda_sync2;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            sda_o        <= 1'b1;       // release SDA
            shift_reg    <= 8'h00;
            data_reg     <= RESET_DATA;
            tx_shift_reg <= RESET_DATA;
            rx_data      <= 8'h00;
            bit_cnt      <= 3'd0;
            ack_phase    <= 1'b0;
            selected     <= 1'b0;
            rw_mode      <= 1'b0;
            master_ack   <= 1'b1;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            // START 조건 감지
            if (start_cond) begin
                state     <= S_ADDR;
                sda_o     <= 1'b1;      // release SDA
                shift_reg <= 8'h00;
                bit_cnt   <= 3'd0;
                ack_phase <= 1'b0;
                selected  <= 1'b0;
            end

            // STOP 조건 감지
            else if (stop_cond) begin
                state     <= S_IDLE;
                sda_o     <= 1'b1;      // release SDA
                bit_cnt   <= 3'd0;
                ack_phase <= 1'b0;
                selected  <= 1'b0;
            end

            else begin
                case (state)

                    S_IDLE: begin
                        sda_o <= 1'b1;
                    end

                    // 주소 byte 수신
                    // [7:1] = slave address, [0] = R/W bit
                    S_ADDR: begin
                        sda_o <= 1'b1;

                        if (scl_posedge) begin
                            shift_reg <= shift_next;

                            if (bit_cnt == 3'd7) begin
                                bit_cnt <= 3'd0;

                                if (shift_next[7:1] == SLAVE_ADDR) begin
                                    selected  <= 1'b1;
                                    rw_mode   <= shift_next[0];
                                    ack_phase <= 1'b0;
                                    state     <= S_ACK_ADDR;
                                end else begin
                                    selected <= 1'b0;
                                    state    <= S_IGNORE;
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 3'd1;
                            end
                        end
                    end

                    // 주소 ACK
                    S_ACK_ADDR: begin
                        // 8번째 bit 끝난 뒤 SCL low 구간에서 ACK 준비
                        if (!ack_phase && scl_negedge) begin
                            sda_o     <= 1'b0;   // ACK = 0
                            ack_phase <= 1'b1;
                        end

                        // ACK clock 끝난 뒤 다음 상태로 이동
                        else if (ack_phase && scl_negedge) begin
                            ack_phase <= 1'b0;
                            bit_cnt   <= 3'd0;

                            if (rw_mode == 1'b0) begin
                                // Master Write, Slave Receive
                                sda_o     <= 1'b1;
                                shift_reg <= 8'h00;
                                state     <= S_RX_DATA;
                            end else begin
                                // Master Read, Slave Transmit
                                tx_shift_reg <= data_reg;
                                sda_o        <= data_reg[7]; // 첫 bit 준비
                                state        <= S_TX_DATA;
                            end
                        end
                    end

                    // Master가 보내는 data byte 수신
                    S_RX_DATA: begin
                        sda_o <= 1'b1;

                        if (scl_posedge) begin
                            shift_reg <= shift_next;

                            if (bit_cnt == 3'd7) begin
                                rx_data   <= shift_next;
                                data_reg  <= shift_next;  // slave 내부 register에 저장
                                bit_cnt   <= 3'd0;
                                ack_phase <= 1'b0;
                                done      <= 1'b1;
                                state     <= S_ACK_RX;
                            end else begin
                                bit_cnt <= bit_cnt + 3'd1;
                            end
                        end
                    end

                    // data byte 수신 후 ACK
                    S_ACK_RX: begin
                        if (!ack_phase && scl_negedge) begin
                            sda_o     <= 1'b0;   // ACK = 0
                            ack_phase <= 1'b1;
                        end else if (ack_phase && scl_negedge) begin
                            sda_o     <= 1'b1;   // release SDA
                            ack_phase <= 1'b0;
                            bit_cnt   <= 3'd0;
                            shift_reg <= 8'h00;
                            state     <= S_RX_DATA; // 다음 data byte도 받을 수 있게 대기
                        end
                    end

                    // Slave가 Master에게 data byte 전송
                    S_TX_DATA: begin
                        if (scl_negedge) begin
                            if (bit_cnt == 3'd7) begin
                                sda_o   <= 1'b1;  // 8bit 전송 후 master ACK/NACK 받기 위해 release
                                bit_cnt <= 3'd0;
                                state   <= S_RX_MACK;
                            end else begin
                                sda_o        <= tx_shift_reg[6];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                bit_cnt      <= bit_cnt + 3'd1;
                            end
                        end
                    end

                    // Master가 read 후 보내는 ACK/NACK 수신
                    S_RX_MACK: begin
                        sda_o <= 1'b1;

                        if (scl_posedge) begin
                            master_ack <= sda_sync2;
                        end

                        if (scl_negedge) begin
                            if (master_ack == 1'b0) begin
                                // Master ACK: 더 읽겠다는 뜻
                                tx_shift_reg <= data_reg;
                                sda_o        <= data_reg[7];
                                bit_cnt      <= 3'd0;
                                state        <= S_TX_DATA;
                            end else begin
                                // Master NACK: read 종료
                                state <= S_IGNORE;
                            end
                        end
                    end

                    // 주소가 안 맞거나 read 끝난 뒤 STOP 기다림
                    S_IGNORE: begin
                        sda_o <= 1'b1;
                    end

                    default: begin
                        state <= S_IDLE;
                        sda_o <= 1'b1;
                    end

                endcase
            end
        end
    end

endmodule
