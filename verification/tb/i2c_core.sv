`timescale 1ns/1ps
module audit_i2c;
reg clk=0,rst=1; always #5 clk=~clk;
reg cmd_start=0,cmd_write=0,cmd_read=0,cmd_stop=0,ack_in=1;
reg[7:0] tx_data=0; wire[7:0] master_rx_data,slave_data_reg,slave_rx_data;
wire ack_out,busy,done,scl_line,sda_line,slave_selected,slave_done;
i2c_top dut(.*);
integer errors=0,k,n; reg[7:0] expected;
task op(input integer kind,input[7:0] value);
begin
 @(negedge clk); tx_data=value;
 cmd_start=(kind==0); cmd_write=(kind==1); cmd_read=(kind==2); cmd_stop=(kind==3);
 @(negedge clk); cmd_start=0;cmd_write=0;cmd_read=0;cmd_stop=0;
 n=0; while(!done && n<50000) begin @(negedge clk); n=n+1; end
 if(n==50000) begin $display("AUDIT I2C TIMEOUT FAIL"); $finish; end
 if(kind==1 && ack_out!==0) begin errors=errors+1; $display("AUDIT I2C ACK FAIL value=%h",value);end
 repeat(5) @(negedge clk);
end endtask
initial begin
 repeat(10) @(negedge clk);rst=0;
 for(k=0;k<16;k=k+1) begin
 expected=k*17;
 op(0,0);op(1,8'h4e);op(1,expected);op(3,0);
 if(slave_data_reg!==expected) begin errors=errors+1;$display("AUDIT I2C WRITE FAIL expected=%h actual=%h",expected,slave_data_reg);end
 op(0,0);op(1,8'h4f);op(2,0);
 if(master_rx_data!==expected) begin errors=errors+1;$display("AUDIT I2C READ FAIL expected=%h actual=%h",expected,master_rx_data);end
 op(3,0);
 end
 $display("AUDIT I2C write-read pairs=16 errors=%0d",errors);
 if(errors==0) $display("AUDIT I2C PASS");$finish;
end
initial begin #100000000; $display("AUDIT I2C GLOBAL TIMEOUT FAIL");$finish;end
endmodule
