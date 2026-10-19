class i2c_base_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_base_seq)

    function new(string name = "i2c_base_seq");
        super.new(name);
    endfunction

    // 기본 전송 태스크
    task do_transfer(bit rw_bit, bit [7:0] wdata=8'h00, 
					 bit ack_in=1, bit [6:0] addr=7'h27);
        i2c_seq_item item;
        item = i2c_seq_item::type_id::create("item");
        start_item(item);
            item.rw_bit = rw_bit;
            item.addr   = addr;
            item.wdata  = wdata;
            item.ack_in = ack_in;
        finish_item(item);
    endtask
endclass


// 고정값 전송 시나리오
class i2c_basic_seq extends i2c_base_seq;
    `uvm_object_utils(i2c_basic_seq)

    int num; // test에서 seq.num 직접 지정

    function new(string name = "i2c_basic_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_type_name(), $sformatf("basic scenario start (%0d repeat)", num), UVM_LOW)

        // 고정 값 주입
		do_transfer(1'b0, 8'h00, 1'b1);  // write 0x00
    	do_transfer(1'b1, 8'h00, 1'b1);  // read → rdata=0x00 (data_zero)

    	do_transfer(1'b0, 8'hFF, 1'b1);  // write 0xFF
    	do_transfer(1'b1, 8'h00, 1'b1);  // read → rdata=0xFF (data_max)

    	do_transfer(1'b0, 8'h55, 1'b1);  // write 중간값
    	do_transfer(1'b1, 8'h00, 1'b1);  // read → rdata=0x55 (data_etc)

        `uvm_info(get_type_name(), "basic scenario end", UVM_LOW)
    endtask
endclass


// 랜덤 전송 시나리오
class i2c_random_seq extends i2c_base_seq;
    `uvm_object_utils(i2c_random_seq)

    int num;

    function new(string name = "i2c_random_seq");
        super.new(name);
    endfunction

    task body();
        i2c_seq_item item;
        `uvm_info(get_type_name(), $sformatf("random scenario start (%0d repeat)", num), UVM_LOW)
        repeat(num) begin
            item = i2c_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_error("SEQ", "randomize fail")
            finish_item(item);
        end

        `uvm_info(get_type_name(), "random scenario end", UVM_LOW)
    endtask
endclass
