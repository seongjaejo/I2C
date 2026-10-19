class i2c_coverage extends uvm_subscriber #(i2c_seq_item);
    `uvm_component_utils(i2c_coverage)

    i2c_seq_item tr;

	covergroup i2c_cg;
	    option.per_instance = 1;
	
	    cp_wdata : coverpoint tr.wdata iff (tr.rw_bit == 1'b0) {
	        bins data_zero = {8'h00};
	        bins data_max  = {8'hFF};
	        bins data_etc  = {[8'h01:8'hFE]};
	    }
	    cp_rdata : coverpoint tr.rdata iff (tr.rw_bit == 1'b1) {
	        bins data_zero = {8'h00};
	        bins data_max  = {8'hFF};
	        bins data_etc  = {[8'h01:8'hFE]};
	    }
	    cp_rw_bit : coverpoint tr.rw_bit {
	        bins write = {1'b0};
	        bins read  = {1'b1};
	    }
	
	    //cp_ack_in : coverpoint tr.ack_in iff (tr.rw_bit == 1'b1) {
	    //    bins ack  = {1'b0};
	    //    bins nack = {1'b1};
	    //}
	
	    //cross_rw_ack : cross cp_rw_bit, cp_ack_in;
	
	endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        i2c_cg = new();
    endfunction

    function void write(i2c_seq_item t);
        tr = t;
        i2c_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", "==========================================", UVM_LOW)
        `uvm_info("COV", "======= Functional Coverage  result ======", UVM_LOW)
        `uvm_info("COV", $sformatf(" total      : %6.2f %%", i2c_cg.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf(" wdata      : %6.2f %%", i2c_cg.cp_wdata.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf(" rdata      : %6.2f %%", i2c_cg.cp_rdata.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf(" rw_bit     : %6.2f %%", i2c_cg.cp_rw_bit.get_inst_coverage()), UVM_LOW)
        //`uvm_info("COV", $sformatf(" ack_in     : %6.2f %%", i2c_cg.cp_ack_in.get_inst_coverage()), UVM_LOW)
        //`uvm_info("COV", $sformatf(" rw x ack   : %6.2f %%", i2c_cg.cross_rw_ack.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", "==========================================", UVM_LOW)
        if (i2c_cg.get_inst_coverage() < 100.0) begin
            `uvm_warning("COV", "Coverage below 100%! Add more test scenarios or perform additional testing.")
        end
    endfunction

endclass
