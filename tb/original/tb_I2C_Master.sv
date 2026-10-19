`timescale 1ns / 1ps
module tb_I2C_Master();
	localparam SLA = 8'h12;

    logic       clk;
    logic       rst;
	// command port
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
	// internal port
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       ack_in;
    logic       ack_out;
    logic       busy;
    logic       done;
	// external i2c port
    logic       scl;
    wire        sda;

	pullup(scl);
	pullup(sda);

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz, SCL 주기 = 250*4*10ns = 10us(100kHz)

    I2C_Master_top dut(.*);

	task i2c_start();
    	cmd_start = 1'b1;
    	cmd_write = 1'b0;
    	cmd_read  = 1'b0;
    	cmd_stop  = 1'b0;
		@(posedge clk);	
		wait (done);
		@(posedge clk);	
	endtask

	task i2c_write(byte data);
		tx_data = data; 
    	cmd_start = 1'b0;
    	cmd_write = 1'b1;
    	cmd_read  = 1'b0;
    	cmd_stop  = 1'b0;
		@(posedge clk);	
		wait (done);
		@(posedge clk);	
	endtask

	task i2c_read(byte data);
    	cmd_start = 1'b0;
    	cmd_write = 1'b0;
    	cmd_read  = 1'b1;
    	cmd_stop  = 1'b0;
		@(posedge clk);	
		wait (done);
		@(posedge clk);	
	endtask

	task i2c_stop();
    	cmd_start = 1'b0;
    	cmd_write = 1'b0;
    	cmd_read  = 1'b0;
    	cmd_stop  = 1'b1;
		@(posedge clk);	
		wait (done);
		@(posedge clk);	
	endtask

	initial begin
		rst = 1;
		repeat (5) @(posedge clk);
		rst = 0;
		@(posedge clk);	

		i2c_start();
		i2c_write(SLA<<1 | 1'b0);
		i2c_write(8'h55);
		i2c_write(8'haa);
		i2c_stop();

		#100;
		$finish;
	end

endmodule
