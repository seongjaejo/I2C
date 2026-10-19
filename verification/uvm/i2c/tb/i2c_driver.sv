class i2c_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_driver)

    virtual i2c_if i_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if))
            `uvm_fatal(get_type_name(), "can't find virtual interface(i_if) from config_db")
    endfunction

    task run_phase(uvm_phase phase);
        // 초기값
        i_if.drv_cb.reset     <= 1;
        i_if.drv_cb.cmd_start <= 0;
        i_if.drv_cb.cmd_write <= 0;
        i_if.drv_cb.cmd_read  <= 0;
        i_if.drv_cb.cmd_stop  <= 0;
        i_if.drv_cb.tx_data   <= 0;
        i_if.drv_cb.ack_in    <= 1;

        // reset 구간
        repeat(3) @(i_if.drv_cb);
        i_if.drv_cb.reset <= 0;
        @(i_if.drv_cb);

        forever begin
            seq_item_port.get_next_item(req);

            // 1. START
            do_start();

            // 2. ADDR + R/W 전송
            do_write({req.addr, req.rw_bit});

            // 3. DATA phase
            if (req.rw_bit == 1'b0) begin
                do_write(req.wdata);
            end else begin
                do_read(req.ack_in);
            end

            // 4. STOP
            do_stop();

            `uvm_info(get_type_name(), $sformatf("run: %s", req.convert2string()), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask

    // ===== I2C 시퀀스 task들 =====

    task do_start();
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_start <= 1;
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_start <= 0;
        @(i_if.drv_cb iff (i_if.drv_cb.done === 1));
    endtask

    task do_write(bit [7:0] data);
        @(i_if.drv_cb);
        i_if.drv_cb.tx_data   <= data;
        i_if.drv_cb.cmd_write <= 1;
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_write <= 0;
        @(i_if.drv_cb iff (i_if.drv_cb.done === 1));
    endtask

    task do_read(bit ack_in);
        @(i_if.drv_cb);
        i_if.drv_cb.ack_in   <= ack_in;
        i_if.drv_cb.cmd_read <= 1;
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_read <= 0;
        @(i_if.drv_cb iff (i_if.drv_cb.done === 1));
    endtask

    task do_stop();
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_stop <= 1;
        @(i_if.drv_cb);
        i_if.drv_cb.cmd_stop <= 0;
        @(i_if.drv_cb iff (i_if.drv_cb.done === 1));
    endtask

endclass
