interface i2c_if (
    input logic clk
);
    // driver 출력 신호 (master 제어)
    logic        reset;
    logic        cmd_start;
    logic        cmd_write;
    logic        cmd_read;
    logic        cmd_stop;
    logic [7:0]  tx_data;
    logic        ack_in;

    // monitor 입력 신호 (master 결과)
    logic [7:0]  rx_data;
    logic        ack_out;
    logic        busy;
    logic        done;

    // monitor 입력 신호 (slave 결과, debug)
    logic [7:0]  slave_data_reg;
    logic [7:0]  slave_rx_data;
    logic        slave_selected;
    logic        slave_done;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output reset;
        output cmd_start;
        output cmd_write;
        output cmd_read;
        output cmd_stop;
        output tx_data;
        output ack_in;
        input  rx_data;
        input  ack_out;
        input  busy;
        input  done;
        input  slave_data_reg;
        input  slave_rx_data;
        input  slave_selected;
        input  slave_done;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input reset;
        input cmd_start;
        input cmd_write;
        input cmd_read;
        input cmd_stop;
        input tx_data;
        input ack_in;
        input rx_data;
        input ack_out;
        input busy;
        input done;
        input slave_data_reg;
        input slave_rx_data;
        input slave_selected;
        input slave_done;
    endclocking

    modport DRV(clocking drv_cb, input clk);
    modport MON(clocking mon_cb, input clk);

endinterface
