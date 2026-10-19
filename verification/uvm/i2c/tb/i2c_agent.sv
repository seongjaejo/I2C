class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)

    uvm_sequencer #(i2c_seq_item) sqr;
    i2c_driver  drv;
    i2c_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("sqr", this);
        drv = i2c_driver::type_id::create("drv", this);
        mon = i2c_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
