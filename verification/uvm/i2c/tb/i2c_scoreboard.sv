class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)

    uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) imp;

    int trans_count = 0;
    int pass_count  = 0;
    int fail_count  = 0;

    // READ 검증을 위해 마지막 WRITE 데이터를 기억
    bit [7:0] last_write_data;
    bit       has_write_data = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    function void write(i2c_seq_item tr);
        bit addr_ok;
        bit ok;

        trans_count++;
        ok = 1'b1;

        // 주소 ACK 공통 검증 (addr=0x27은 slave_addr와 일치하므로 항상 ACK=0 기대)
        addr_ok = (tr.addr_ack === 1'b0);
        if (!addr_ok) ok = 1'b0;

        if (tr.rw_bit == 1'b0) begin
            // ---- WRITE 검증 ----
            bit data_ack_ok;
            bit slave_rx_ok;

            data_ack_ok = (tr.ack_out === 1'b0);
            slave_rx_ok = (tr.slave_rx_data === tr.wdata);

            if (!data_ack_ok) ok = 1'b0;
            if (!slave_rx_ok) ok = 1'b0;

            if (ok) begin
                pass_count++;
                `uvm_info(get_type_name(), $sformatf(
                    "PASS [WRITE] %s", tr.convert2string()), UVM_HIGH)
            end else begin
                fail_count++;
                if (!addr_ok)
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL [addr_ack] addr=0x%02h ack=%0d (expect 0)", tr.addr, tr.addr_ack))
                if (!data_ack_ok)
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL [ack_out] wdata=0x%02h ack_out=%0d (expect 0)", tr.wdata, tr.ack_out))
                if (!slave_rx_ok)
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL [slave_rx] wdata=0x%02h slave_rx=0x%02h", tr.wdata, tr.slave_rx_data))
            end

            // READ 비교용으로 저장
            last_write_data = tr.wdata;
            has_write_data  = 1'b1;

        end else begin
            // ---- READ 검증 ----
            bit rdata_ok;

            if (has_write_data) begin
                rdata_ok = (tr.rdata === last_write_data);
            end else begin
                // 아직 write 안 했으면 i2c_slave의 RESET_DATA(0xA5)와 비교
                rdata_ok = (tr.rdata === 8'hA5);
            end

            if (!rdata_ok) ok = 1'b0;

            if (ok) begin
                pass_count++;
                `uvm_info(get_type_name(), $sformatf(
                    "PASS [READ] %s", tr.convert2string()), UVM_HIGH)
            end else begin
                fail_count++;
                if (!addr_ok)
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL [addr_ack] addr=0x%02h ack=%0d (expect 0)", tr.addr, tr.addr_ack))
                if (!rdata_ok)
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL [rdata] rdata=0x%02h expect=0x%02h", tr.rdata,
                        has_write_data ? last_write_data : 8'hA5))
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", "==================================", UVM_LOW)
        `uvm_info("SCB", "=========Scoreboard report========", UVM_LOW)
        `uvm_info("SCB", $sformatf("  trans   count : %0d", trans_count), UVM_LOW)
        `uvm_info("SCB", $sformatf("  pass    count : %0d", pass_count),  UVM_LOW)
        `uvm_info("SCB", $sformatf("  fail    count : %0d", fail_count),  UVM_LOW)
        `uvm_info("SCB", "==================================", UVM_LOW)
    endfunction

endclass
