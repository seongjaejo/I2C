`timescale 1ns / 1ps

module tb_i2c_top;

    logic       clk;
    logic       rst;

    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;

    logic [7:0] tx_data;
    logic       ack_in;

    logic [7:0] master_rx_data;
    logic       ack_out;
    logic       busy;
    logic       done;

    logic       scl_line;
    logic       sda_line;

    logic [7:0] slave_data_reg;
    logic [7:0] slave_rx_data;
    logic       slave_selected;
    logic       slave_done;

    logic [7:0] read_data;

    // 100MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    i2c_top dut (
        .clk            (clk),
        .rst            (rst),

        .cmd_start      (cmd_start),
        .cmd_write      (cmd_write),
        .cmd_read       (cmd_read),
        .cmd_stop       (cmd_stop),

        .tx_data        (tx_data),
        .ack_in         (ack_in),

        .master_rx_data (master_rx_data),
        .ack_out        (ack_out),
        .busy           (busy),
        .done           (done),

        .scl_line       (scl_line),
        .sda_line       (sda_line),

        .slave_data_reg (slave_data_reg),
        .slave_rx_data  (slave_rx_data),
        .slave_selected (slave_selected),
        .slave_done     (slave_done)
    );

    // Task: reset
    task automatic reset_dut();
        begin
            rst       = 1'b1;
            cmd_start = 1'b0;
            cmd_write = 1'b0;
            cmd_read  = 1'b0;
            cmd_stop  = 1'b0;
            tx_data   = 8'h00;
            ack_in    = 1'b1;   // default NACK

            repeat (10) @(posedge clk);
            rst = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    // Task: wait until master operation done
    task automatic wait_master_done();
        begin
            wait (done == 1'b1);
            @(posedge clk);
        end
    endtask

    // Task: I2C START
    task automatic i2c_start();
        begin
            @(negedge clk);
            cmd_start = 1'b1;

            @(negedge clk);
            cmd_start = 1'b0;

            wait_master_done();

            $display("[%0t] START done", $time);
        end
    endtask

    // Task: I2C WRITE 1 byte
    task automatic i2c_write_byte(input logic [7:0] data);
        begin
            @(negedge clk);
            tx_data   = data;
            cmd_write = 1'b1;

            @(negedge clk);
            cmd_write = 1'b0;

            wait_master_done();

            $display("[%0t] WRITE data = 0x%02h, ack_out = %0b",
                     $time, data, ack_out);
        end
    endtask

    // Task: I2C READ 1 byte
    // ack_value = 0 : ACK, more read
    // ack_value = 1 : NACK, last byte
    task automatic i2c_read_byte(
        input  logic       ack_value,
        output logic [7:0] data
    );
        begin
            @(negedge clk);
            ack_in   = ack_value;
            cmd_read = 1'b1;

            @(negedge clk);
            cmd_read = 1'b0;

            wait_master_done();

            data = master_rx_data;

            $display("[%0t] READ data = 0x%02h, master ack_in = %0b",
                     $time, data, ack_value);
        end
    endtask

    // Task: I2C STOP
    task automatic i2c_stop();
        begin
            @(negedge clk);
            cmd_stop = 1'b1;

            @(negedge clk);
            cmd_stop = 1'b0;

            wait_master_done();

            $display("[%0t] STOP done", $time);
        end
    endtask

    // Main test
    initial begin
        $dumpfile("i2c_top_wave.vcd");
        $dumpvars(0, tb_i2c_top);

        reset_dut();

        $display("========================================");
        $display(" I2C WRITE TEST: slave address = 0x27");
        $display("========================================");

        // Slave address = 7'h27
        // Write address byte = {7'h27, 1'b0} = 8'h4E
        i2c_start();
        i2c_write_byte(8'h4E);   // address + write
        i2c_write_byte(8'h12);   // data
        i2c_stop();

        repeat (20) @(posedge clk);

        if (slave_data_reg == 8'h12) begin
            $display("[PASS] Slave data_reg = 0x%02h", slave_data_reg);
        end else begin
            $display("[FAIL] Slave data_reg = 0x%02h, expected 0x12",
                     slave_data_reg);
        end

        $display("========================================");
        $display(" I2C READ TEST: master reads slave data");
        $display("========================================");

        // Read address byte = {7'h27, 1'b1} = 8'h4F
        i2c_start();
        i2c_write_byte(8'h4F);       // address + read
        i2c_read_byte(1'b1, read_data); // 1 byte만 읽으니까 NACK
        i2c_stop();

        repeat (20) @(posedge clk);

        if (read_data == 8'h12) begin
            $display("[PASS] Master read_data = 0x%02h", read_data);
        end else begin
            $display("[FAIL] Master read_data = 0x%02h, expected 0x12",
                     read_data);
        end

        $display("========================================");
        $display(" Simulation Finish");
        $display("========================================");

        #1000;
        $finish;
    end

endmodule
