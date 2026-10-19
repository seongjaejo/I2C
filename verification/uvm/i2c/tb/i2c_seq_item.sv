class i2c_seq_item extends uvm_sequence_item;

    rand bit        rw_bit;
    rand bit [6:0]  addr;
    rand bit [7:0]  wdata;
    rand bit        ack_in;
         bit [7:0]  rdata;
         bit        ack_out;
         bit        addr_ack;
         bit        done;
         bit [7:0]  slave_rx_data;   

	// slave 주소 고정
    constraint c_addr { addr == 7'h27; }
	// 1byte read 후 NACK 고정
    constraint c_ack_in { ack_in == 1'b1; }

    `uvm_object_utils_begin(i2c_seq_item)
        `uvm_field_int(rw_bit,        UVM_ALL_ON)
        `uvm_field_int(addr,          UVM_ALL_ON)
        `uvm_field_int(wdata,         UVM_ALL_ON)
        `uvm_field_int(ack_in,        UVM_ALL_ON)
        `uvm_field_int(rdata,         UVM_ALL_ON)
        `uvm_field_int(ack_out,       UVM_ALL_ON)
        `uvm_field_int(addr_ack,      UVM_ALL_ON)
        `uvm_field_int(done,          UVM_ALL_ON)
        `uvm_field_int(slave_rx_data, UVM_ALL_ON)  
    `uvm_object_utils_end

    function new(string name = "i2c_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "rw=%0d addr=0x%02h | wdata=0x%02h ack_in=%0d | rdata=0x%02h ack_out=%0d addr_ack=%0d slave_rx=0x%02h done=%0d",
            rw_bit, addr, wdata, ack_in, rdata, ack_out, addr_ack, slave_rx_data, done);
    endfunction

endclass
