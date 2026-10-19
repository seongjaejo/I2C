class i2c_base_test extends uvm_test;
    `uvm_component_utils(i2c_base_test)

    i2c_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = i2c_env::type_id::create("env", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass


class i2c_basic_test extends i2c_base_test;
    `uvm_component_utils(i2c_basic_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_basic_seq seq;
        phase.raise_objection(this);
        seq = i2c_basic_seq::type_id::create("seq");
        seq.num = 200;
        seq.start(env.agt.sqr);
        #100;
        phase.drop_objection(this);
    endtask
endclass


class i2c_random_test extends i2c_base_test;
    `uvm_component_utils(i2c_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_random_seq seq;
        phase.raise_objection(this);
        seq = i2c_random_seq::type_id::create("seq");
        seq.num = 700;
        seq.start(env.agt.sqr);
        #100;
        phase.drop_objection(this);
    endtask
endclass
