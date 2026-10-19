class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)

    virtual i2c_if i_if;
    uvm_analysis_port #(i2c_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if))
            `uvm_fatal(get_type_name(), "can't find virtual interface(i_if) from config_db")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item tr;
        bit prev_done;
        int done_cnt;
        bit rw_bit_latched;

        prev_done = 0;
        done_cnt  = 0;

        forever begin
            @(i_if.mon_cb);

            // done이 0->1로 막 바뀐 클럭만 카운트 (펄스 검출)
            if (i_if.mon_cb.done === 1 && prev_done === 0) begin
                done_cnt++;

                case (done_cnt)
                    1: begin
                        // START 완료 - 아직 캡처할 정보 없음
                        tr = i2c_seq_item::type_id::create("tr");
                    end

                    2: begin
                        // ADDR+RW phase 완료
                        rw_bit_latched = i_if.mon_cb.tx_data[0];
                        tr.rw_bit   = rw_bit_latched;
                        tr.addr     = i_if.mon_cb.tx_data[7:1];
                        tr.addr_ack = i_if.mon_cb.ack_out;
                    end

					3: begin
					    // DATA phase 완료
					    if (rw_bit_latched == 1'b0) begin
					        tr.wdata         = i_if.mon_cb.tx_data;
					        tr.ack_out       = i_if.mon_cb.ack_out;
					        tr.slave_rx_data = i_if.mon_cb.slave_rx_data; 
					    end else begin
					        tr.rdata  = i_if.mon_cb.rx_data;
					        tr.ack_in = i_if.mon_cb.ack_in;
					    end
					end

                    4: begin
                        // STOP 완료 -> 트랜잭션 1개 종료
                        tr.done = 1'b1;
                        `uvm_info(get_type_name(), $sformatf("%s", tr.convert2string()), UVM_MEDIUM)
                        ap.write(tr);
                        done_cnt = 0;
                    end
                endcase
            end

            prev_done = i_if.mon_cb.done;
        end
    endtask

endclass
