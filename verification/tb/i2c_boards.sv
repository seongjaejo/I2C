`timescale 1ns/1ps
module audit_i2c_board;
reg clk=0,rst=0,btn_right=0;always #5 clk=~clk;
reg[15:0]sw=0;wire scl;tri1 sda;
wire[3:0]mcom,scom;wire[7:0]mdata,sdata;
i2c_master_board_top m(.clk(clk),.rst(rst),.btn_right(btn_right),.sw(sw),.scl(scl),.sda(sda),.fnd_com(mcom),.fnd_data(mdata));
i2c_slave_board_top s(.clk(clk),.rst(rst),.scl(scl),.sda(sda),.fnd_com(scom),.fnd_data(sdata));
integer k,n,errors=0;reg[7:0]value;
always @(posedge clk) if(m.btn_right_pulse)$display("AUDIT BUTTON PULSE at %0t",$time);
task transfer(input[15:0]v);
begin
 @(negedge clk);sw=v;btn_right=1;repeat(9000)@(negedge clk);$display("AUDIT BUTTON shift=%h state=%0d",m.U_BTN_RIGHT.sync_reg,m.board_state);btn_right=0;
 repeat(9000)@(negedge clk);
 n=0;while(m.board_state!=6&&n<100000)begin @(negedge clk);n=n+1;end
 repeat(20)@(negedge clk);
 if(n==100000)begin $display("AUDIT BOARD TIMEOUT FAIL board=%0d core=%0d done=%b pulse=%b shift=%h scl=%b sda=%b",m.board_state,m.U_I2C_MASTER.state,m.done,m.btn_right_pulse,m.U_BTN_RIGHT.sync_reg,scl,sda);$finish;end
end endtask
initial begin
 #1;rst=1;
 repeat(10)@(negedge clk);rst=0;
 for(k=0;k<4;k=k+1)begin
 value=8'h35+k*37;
 transfer({8'hca,value});
 if(s.slave1_data_reg_out!==value)begin errors=errors+1;$display("AUDIT BOARD WRITE FAIL %h %h",value,s.slave1_data_reg_out);end
 transfer(16'hcb00);
 if(m.display_data!==value)begin errors=errors+1;$display("AUDIT BOARD READ FAIL %h %h",value,m.display_data);end
 end
 $display("AUDIT I2C BOARD pairs=4 errors=%0d",errors);if(errors==0)$display("AUDIT I2C BOARD PASS");$finish;
end
initial begin #20000000;$display("AUDIT BOARD GLOBAL TIMEOUT FAIL");$finish;end
endmodule
