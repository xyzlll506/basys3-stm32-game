`timescale 1ns / 1ps
// 8 data bits, no parity, one stop bit. Input is synchronized to clk.
module uart_rx #(
    parameter integer CLK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst,
    input wire rx_i,
    output reg [7:0] data_o,
    output reg valid_o,
    output reg framing_error_o
);
    localparam integer BIT_CLKS = (CLK_HZ + BAUD / 2) / BAUD;
    localparam integer HALF_CLKS = BIT_CLKS / 2;
    localparam [2:0] IDLE=0, START=1, DATA=2, STOP=3, WAIT_HIGH=4;
    (* ASYNC_REG = "TRUE" *) reg rx_meta;
    (* ASYNC_REG = "TRUE" *) reg rx_sync;
    reg [2:0] state;
    reg [31:0] ticks;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_i;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ticks <= 0;
            bit_index <= 0;
            shift <= 0;
            data_o <= 0;
            valid_o <= 0;
            framing_error_o <= 0;
        end else begin
            valid_o <= 0;
            framing_error_o <= 0;
            case (state)
                IDLE: if (!rx_sync) begin
                    ticks <= HALF_CLKS - 1;
                    state <= START;
                end
                START: if (ticks != 0) ticks <= ticks - 1;
                    else if (!rx_sync) begin
                        ticks <= BIT_CLKS - 1;
                        bit_index <= 0;
                        state <= DATA;
                    end else state <= IDLE; // reject a short low glitch
                DATA: if (ticks != 0) ticks <= ticks - 1;
                    else begin
                        shift[bit_index] <= rx_sync;
                        ticks <= BIT_CLKS - 1;
                        if (bit_index == 7) state <= STOP;
                        else bit_index <= bit_index + 1'b1;
                    end
                STOP: if (ticks != 0) ticks <= ticks - 1;
                    else if (rx_sync) begin
                        data_o <= shift;
                        valid_o <= 1;
                        state <= IDLE;
                    end else begin
                        framing_error_o <= 1;
                        state <= WAIT_HIGH;
                    end
                WAIT_HIGH: if (rx_sync) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
