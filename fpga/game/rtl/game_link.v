`timescale 1ns / 1ps
`include "level.vh"
// FPGA is the game protocol master. This is separate from the UART starter.
module game_link #(
    parameter integer CLK_HZ = 25200000,
    parameter integer BAUD = 115200,
    parameter integer TIMEOUT_CLKS = CLK_HZ / 125
) (
    input wire clk, input wire rst, input wire frame_tick,
    input wire [3:0] buttons, input wire rx, output wire tx,
    output reg [9:0] player_x, output reg [9:0] player_y,
    output reg [7:0] flags, output reg [15:0] deaths,
    output wire link_live, output reg good_toggle, output reg error_toggle
);
    wire [7:0] rx_data;
    wire rx_valid, framing_error;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk), .rst(rst), .rx_i(rx), .data_o(rx_data),
        .valid_o(rx_valid), .framing_error_o(framing_error)
    );
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) transmitter (
        .clk(clk), .rst(rst), .start_i(tx_start), .data_i(tx_data),
        .tx_o(tx), .busy_o(tx_busy)
    );
    localparam [1:0] TX_IDLE=0, TX_ISSUE=1, TX_ACCEPT=2, TX_FINISH=3;
    reg [1:0] tx_state, tx_index;
    reg [31:0] tx_frame;
    reg [7:0] next_seq, active_seq;
    reg active_transaction;
    reg [31:0] timeout_ticks;
    reg [3:0] rx_index;
    reg [7:0] rx_xor, reply_seq, reply_flags;
    reg [15:0] reply_x, reply_y, reply_deaths;
    reg reserved_ok;
    reg pending_valid;
    reg [9:0] pending_x, pending_y;
    reg [7:0] pending_flags;
    reg [15:0] pending_deaths;
    reg [6:0] frames_since_reply;
    assign link_live = frames_since_reply < 60;
    wire reply_good = rx_valid && rx_index == 11 &&
        rx_data == rx_xor && reply_seq == active_seq && reserved_ok &&
        reply_flags[7:3] == 0 &&
        reply_x <= 640 - `LEVEL_PLAYER_W && reply_y <= 480 - `LEVEL_PLAYER_H;

    always @(posedge clk) begin
        if (rst) begin
            player_x <= `LEVEL_SPAWN_X; player_y <= `LEVEL_SPAWN_Y;
            flags <= 0; deaths <= 0;
            next_seq <= 0; active_seq <= 0;
            active_transaction <= 0; timeout_ticks <= 0;
            tx_state <= TX_IDLE; tx_index <= 0; tx_frame <= 0;
            tx_start <= 0; tx_data <= 0;
            rx_index <= 0; rx_xor <= 0; reply_seq <= 0;
            reply_x <= 0; reply_y <= 0; reply_flags <= 0;
            reply_deaths <= 0; reserved_ok <= 1;
            pending_valid <= 0; pending_x <= 0; pending_y <= 0;
            pending_flags <= 0; pending_deaths <= 0;
            frames_since_reply <= 60; good_toggle <= 0; error_toggle <= 0;
        end else begin
            tx_start <= 0;
            if (frame_tick) begin
                if (frames_since_reply < 60) frames_since_reply <= frames_since_reply + 1'b1;
                if (pending_valid) begin
                    player_x <= pending_x; player_y <= pending_y;
                    flags <= pending_flags; deaths <= pending_deaths;
                    pending_valid <= 0;
                end
                if (!active_transaction && tx_state == TX_IDLE) begin
                    active_transaction <= 1;
                    active_seq <= next_seq;
                    tx_frame <= {8'hA5 ^ next_seq ^ {4'b0000, buttons},
                                 4'b0000, buttons, next_seq, 8'hA5};
                    next_seq <= next_seq + 1'b1;
                    tx_index <= 0; tx_state <= TX_ISSUE;
                    timeout_ticks <= 0; rx_index <= 0;
                end
            end
            case (tx_state)
                TX_ISSUE: if (!tx_busy) begin
                    case (tx_index)
                        0: tx_data <= tx_frame[7:0];
                        1: tx_data <= tx_frame[15:8];
                        2: tx_data <= tx_frame[23:16];
                        3: tx_data <= tx_frame[31:24];
                    endcase
                    tx_start <= 1; tx_state <= TX_ACCEPT;
                end
                TX_ACCEPT: if (tx_busy) tx_state <= TX_FINISH;
                TX_FINISH: if (!tx_busy) begin
                    if (tx_index == 3) tx_state <= TX_IDLE;
                    else begin tx_index <= tx_index + 1'b1; tx_state <= TX_ISSUE; end
                end
                default: begin end
            endcase

            if (active_transaction) begin
                timeout_ticks <= timeout_ticks + 1'b1;
                if (timeout_ticks >= TIMEOUT_CLKS - 1) begin
                    active_transaction <= 0; rx_index <= 0;
                    error_toggle <= ~error_toggle;
                end else if (framing_error) begin
                    active_transaction <= 0; rx_index <= 0;
                    error_toggle <= ~error_toggle;
                end else if (rx_valid) begin
                    if (rx_index == 0) begin
                        if (rx_data == 8'h5A) begin
                            rx_index <= 1; rx_xor <= 8'h5A; reserved_ok <= 1;
                        end
                    end else if (rx_index == 11) begin
                        active_transaction <= 0; rx_index <= 0;
                        if (reply_good) begin
                            pending_x <= reply_x[9:0]; pending_y <= reply_y[9:0];
                            pending_flags <= reply_flags; pending_deaths <= reply_deaths;
                            pending_valid <= 1; frames_since_reply <= 0;
                            good_toggle <= ~good_toggle;
                        end else error_toggle <= ~error_toggle;
                    end else begin
                        rx_index <= rx_index + 1'b1;
                        rx_xor <= rx_xor ^ rx_data;
                        case (rx_index)
                            1: reply_seq <= rx_data;
                            2: reply_x[7:0] <= rx_data;
                            3: reply_x[15:8] <= rx_data;
                            4: reply_y[7:0] <= rx_data;
                            5: reply_y[15:8] <= rx_data;
                            6: reply_flags <= rx_data;
                            7: reply_deaths[7:0] <= rx_data;
                            8: reply_deaths[15:8] <= rx_data;
                            9,10: if (rx_data != 0) reserved_ok <= 0;
                            default: begin end
                        endcase
                    end
                end
            end
        end
    end
endmodule
