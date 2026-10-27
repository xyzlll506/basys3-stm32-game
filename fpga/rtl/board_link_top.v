`timescale 1ns / 1ps
// Request : A5 sequence data (A5 XOR sequence XOR data)
// Response: 5A sequence data (5A XOR sequence XOR data)
// Byte order is left to right. UART is 115200, 8-N-1, 3.3 V logic.
module board_link_top #(
    parameter integer CLK_HZ = 100000000,
    parameter integer BAUD = 115200,
    parameter integer RX_TIMEOUT_CLKS = CLK_HZ / 50
) (
    input wire clk100,
    input wire btnC,
    input wire uart_rx,
    output wire uart_tx,
    output wire [15:0] led
);
    // Artix-7 supports register initialization in the configuration bitstream.
    // Hold reset through startup; btnC also asynchronously asserts reset.
    reg [15:0] por_count = 0;
    reg por_done = 0;
    always @(posedge clk100) begin
        if (!por_done) begin
            if (&por_count) por_done <= 1;
            else por_count <= por_count + 1'b1;
        end
    end
    wire reset_request = btnC | ~por_done;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;
    always @(posedge clk100 or posedge reset_request) begin
        if (reset_request) reset_pipe <= 2'b11;
        else reset_pipe <= {reset_pipe[0], 1'b0};
    end
    wire rst = reset_pipe[1];

    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_framing_error;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk100), .rst(rst), .rx_i(uart_rx),
        .data_o(rx_data), .valid_o(rx_valid),
        .framing_error_o(rx_framing_error)
    );
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) transmitter (
        .clk(clk100), .rst(rst), .start_i(tx_start), .data_i(tx_data),
        .tx_o(uart_tx), .busy_o(tx_busy)
    );

    reg [1:0] rx_state;
    reg [7:0] request_sequence;
    reg [7:0] request_payload;
    reg [31:0] rx_idle_ticks;
    wire packet_good = rx_valid && (rx_state == 3) &&
        (rx_data == (8'hA5 ^ request_sequence ^ request_payload));
    wire packet_bad = rx_valid && (rx_state == 3) && !packet_good;

    always @(posedge clk100) begin
        if (rst) begin
            rx_state <= 0;
            request_sequence <= 0;
            request_payload <= 0;
            rx_idle_ticks <= 0;
        end else if (rx_framing_error) begin
            rx_state <= 0;
            rx_idle_ticks <= 0;
        end else if (rx_valid) begin
            rx_idle_ticks <= 0;
            case (rx_state)
                0: if (rx_data == 8'hA5) rx_state <= 1;
                1: begin request_sequence <= rx_data; rx_state <= 2; end
                2: begin request_payload <= rx_data; rx_state <= 3; end
                3: begin
                    // A bad checksum that is itself A5 may be a new header.
                    if (!packet_good && rx_data == 8'hA5) rx_state <= 1;
                    else rx_state <= 0;
                end
            endcase
        end else if (rx_state != 0) begin
            if (rx_idle_ticks >= RX_TIMEOUT_CLKS - 1) begin
                rx_state <= 0;
                rx_idle_ticks <= 0;
            end else rx_idle_ticks <= rx_idle_ticks + 1'b1;
        end else rx_idle_ticks <= 0;
    end

    // One pending packet can wait while one response is being transmitted.
    // This starter expects one request per 500 ms. If more than this queue can
    // hold arrive, the newest excess response is dropped; it is not retried.
    localparam [1:0] TX_IDLE=0, TX_ISSUE=1, TX_ACCEPT=2, TX_FINISH=3;
    reg [1:0] tx_state;
    reg pending_valid;
    reg [7:0] pending_sequence;
    reg [7:0] pending_payload;
    reg [31:0] reply_frame;
    reg [1:0] reply_index;
    wire take_pending = (tx_state == TX_IDLE) && pending_valid;

    always @(posedge clk100) begin
        if (rst) begin
            pending_valid <= 0;
            pending_sequence <= 0;
            pending_payload <= 0;
        end else begin
            if (take_pending) pending_valid <= 0;
            if (packet_good && (!pending_valid || take_pending)) begin
                pending_valid <= 1;
                pending_sequence <= request_sequence;
                pending_payload <= request_payload;
            end
        end
    end

    always @(posedge clk100) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_start <= 0;
            tx_data <= 0;
            reply_frame <= 0;
            reply_index <= 0;
        end else begin
            tx_start <= 0;
            case (tx_state)
                TX_IDLE: if (take_pending) begin
                    reply_frame <= {8'h5A ^ pending_sequence ^ pending_payload,
                                    pending_payload, pending_sequence, 8'h5A};
                    reply_index <= 0;
                    tx_state <= TX_ISSUE;
                end
                TX_ISSUE: if (!tx_busy) begin
                    case (reply_index)
                        0: tx_data <= reply_frame[7:0];
                        1: tx_data <= reply_frame[15:8];
                        2: tx_data <= reply_frame[23:16];
                        3: tx_data <= reply_frame[31:24];
                    endcase
                    tx_start <= 1;
                    tx_state <= TX_ACCEPT;
                end
                // Wait for an actual busy assertion, not just one fixed cycle.
                TX_ACCEPT: if (tx_busy) tx_state <= TX_FINISH;
                TX_FINISH: if (!tx_busy) begin
                    if (reply_index == 3) tx_state <= TX_IDLE;
                    else begin
                        reply_index <= reply_index + 1'b1;
                        tx_state <= TX_ISSUE;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    reg [31:0] heartbeat_ticks;
    reg heartbeat;
    reg good_toggle;
    reg error_toggle;
    reg [7:0] last_payload;
    always @(posedge clk100) begin
        if (rst) begin
            heartbeat_ticks <= 0;
            heartbeat <= 0;
            good_toggle <= 0;
            error_toggle <= 0;
            last_payload <= 0;
        end else begin
            if (heartbeat_ticks >= CLK_HZ / 2 - 1) begin
                heartbeat_ticks <= 0;
                heartbeat <= ~heartbeat;
            end else heartbeat_ticks <= heartbeat_ticks + 1'b1;
            if (packet_good) begin
                good_toggle <= ~good_toggle;
                last_payload <= request_payload;
            end
            if (packet_bad || rx_framing_error) error_toggle <= ~error_toggle;
        end
    end
    assign led = {last_payload, 5'b00000, error_toggle, good_toggle, heartbeat};
endmodule
