`timescale 1ns / 1ps
// start_i is accepted for one clock only when busy_o is low.
module uart_tx #(
    parameter integer CLK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst,
    input wire start_i,
    input wire [7:0] data_i,
    output reg tx_o,
    output reg busy_o
);
    localparam integer BIT_CLKS = (CLK_HZ + BAUD / 2) / BAUD;
    localparam [1:0] IDLE=0, START=1, DATA=2, STOP=3;
    reg [1:0] state;
    reg [31:0] ticks;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ticks <= 0;
            bit_index <= 0;
            shift <= 0;
            tx_o <= 1;
            busy_o <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_o <= 1;
                    busy_o <= 0;
                    if (start_i) begin
                        shift <= data_i;
                        bit_index <= 0;
                        ticks <= BIT_CLKS - 1;
                        tx_o <= 0;
                        busy_o <= 1;
                        state <= START;
                    end
                end
                START: if (ticks != 0) ticks <= ticks - 1;
                    else begin
                        tx_o <= shift[0];
                        ticks <= BIT_CLKS - 1;
                        state <= DATA;
                    end
                DATA: if (ticks != 0) ticks <= ticks - 1;
                    else begin
                        ticks <= BIT_CLKS - 1;
                        if (bit_index == 7) begin
                            tx_o <= 1;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx_o <= shift[bit_index + 1'b1];
                        end
                    end
                STOP: if (ticks != 0) ticks <= ticks - 1;
                    else begin
                        busy_o <= 0;
                        state <= IDLE;
                    end
                default: begin
                    tx_o <= 1;
                    busy_o <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
