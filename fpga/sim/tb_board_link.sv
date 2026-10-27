`timescale 1ns / 1ps
module tb_board_link;
    reg clk100 = 0;
    always #5 clk100 = ~clk100;
    reg btnC = 1;
    reg uart_rx = 1;
    wire uart_tx;
    wire [15:0] led;
    // Only shorten the partial-packet timeout to keep simulation fast.
    // UART bit timing and 100 MHz clock are the production settings.
    board_link_top #(.RX_TIMEOUT_CLKS(30000)) dut (
        .clk100(clk100), .btnC(btnC), .uart_rx(uart_rx),
        .uart_tx(uart_tx), .led(led)
    );
    localparam integer BIT_NS = 8680;
    reg [7:0] captured [0:255];
    integer captured_count = 0;
    integer i;
    reg [7:0] observed;

    task automatic send_byte(input [7:0] value, input integer bit_ns);
        integer bit_no;
        begin
            uart_rx = 0;
            #(bit_ns);
            for (bit_no=0; bit_no<8; bit_no=bit_no+1) begin
                uart_rx = value[bit_no];
                #(bit_ns);
            end
            uart_rx = 1;
            #(bit_ns);
        end
    endtask
    task automatic send_frame(input [7:0] seq, input [7:0] payload,
                              input integer bad_checksum, input integer bit_ns);
        reg [7:0] check;
        begin
            check = 8'hA5 ^ seq ^ payload;
            if (bad_checksum) check = check ^ 8'h01;
            send_byte(8'hA5, bit_ns);
            send_byte(seq, bit_ns);
            send_byte(payload, bit_ns);
            send_byte(check, bit_ns);
        end
    endtask
    task automatic wait_count(input integer target);
        integer clocks;
        begin
            clocks = 0;
            while (captured_count < target && clocks < 200000) begin
                @(posedge clk100);
                clocks = clocks + 1;
            end
            if (captured_count < target)
                $fatal(1, "Reply timeout: expected %0d bytes, got %0d", target, captured_count);
        end
    endtask
    task automatic expect_reply(input integer base, input [7:0] seq,
                                input [7:0] payload);
        begin
            wait_count(base + 4);
            if (captured[base] !== 8'h5A || captured[base+1] !== seq ||
                captured[base+2] !== payload ||
                captured[base+3] !== (8'h5A ^ seq ^ payload))
                $fatal(1, "Bad reply at byte %0d: %02x %02x %02x %02x", base,
                    captured[base], captured[base+1], captured[base+2], captured[base+3]);
        end
    endtask

    // Decode the actual serial output, including start and stop-bit timing.
    initial begin
        forever begin
            @(negedge uart_tx);
            #(BIT_NS / 2);
            if (uart_tx !== 0) $fatal(1, "Invalid transmitted start bit");
            for (i=0; i<8; i=i+1) begin
                #(BIT_NS);
                observed[i] = uart_tx;
            end
            #(BIT_NS);
            if (uart_tx !== 1) $fatal(1, "Invalid transmitted stop bit");
            captured[captured_count] = observed;
            captured_count = captured_count + 1;
        end
    end

    initial begin
        #200;
        btnC = 0;
        #800000; // power-on reset has completed

        send_frame(8'h12, 8'h34, 0, BIT_NS);
        expect_reply(0, 8'h12, 8'h34);
        if (led[15:8] !== 8'h34 || led[1] !== 1)
            $fatal(1, "Valid packet LEDs did not update");

        send_frame(8'h99, 8'h21, 1, BIT_NS);
        #500000;
        if (captured_count != 4 || led[2] !== 1)
            $fatal(1, "Bad checksum should not receive a reply");

        send_byte(8'hA5, BIT_NS);
        send_byte(8'h55, BIT_NS);
        #500000; // partial frame expires after 300 us
        send_frame(8'hA5, 8'h5A, 0, BIT_NS);
        expect_reply(4, 8'hA5, 8'h5A);

        send_frame(8'h5A, 8'hA5, 0, BIT_NS); // headers are legal sequence/payload
        expect_reply(8, 8'h5A, 8'hA5);

        send_frame(8'h15, 8'hC3, 0, 8500); // transmitter about 2% faster
        expect_reply(12, 8'h15, 8'hC3);

        send_frame(8'h16, 8'h11, 0, BIT_NS);
        send_frame(8'h17, 8'h22, 0, BIT_NS); // no gap between packets
        expect_reply(16, 8'h16, 8'h11);
        expect_reply(20, 8'h17, 8'h22);

        // Deliberately invalid stop bit, then recovery to an idle-high line.
        uart_rx = 0;
        #(BIT_NS * 12);
        uart_rx = 1;
        #(BIT_NS * 2);
        send_frame(8'h18, 8'h44, 0, BIT_NS);
        expect_reply(24, 8'h18, 8'h44);

        send_byte(8'hA5, BIT_NS);
        send_byte(8'h30, BIT_NS);
        btnC = 1;
        #200;
        btnC = 0;
        #200;
        send_byte(8'h11, BIT_NS); // obsolete tail must not produce a reply
        send_byte(8'h84, BIT_NS);
        #500000;
        if (captured_count != 28) $fatal(1, "Reset failed to discard a partial packet");
        send_frame(8'h19, 8'h77, 0, BIT_NS);
        expect_reply(28, 8'h19, 8'h77);
        #100000;
        if (captured_count != 32 || led[15:8] !== 8'h77)
            $fatal(1, "Unexpected extra reply or wrong payload LED state");

        send_frame(8'h99, 8'h21, 1, BIT_NS);
        send_frame(8'h5A, 8'hA5, 0, 8850); // valid packet immediately follows bad;
        expect_reply(32, 8'h5A, 8'hA5);     // transmitter about 2% slower
        #100000;
        if (captured_count != 36) $fatal(1, "Bad packet produced an extra reply");
        $display("PASS: UART framing, valid/bad packets, A5/5A data, partial timeout, +/-2%% baud offset, back-to-back packets, reset recovery");
        $finish;
    end
    initial begin
        #20000000;
        $fatal(1, "Global simulation timeout");
    end
endmodule
