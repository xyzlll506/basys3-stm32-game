`timescale 1ns / 1ps
module button_filter #(
    parameter integer STABLE_CLKS = 126000
) (
    input wire clk, input wire rst, input wire button,
    output reg value
);
    (* ASYNC_REG = "TRUE" *) reg meta;
    (* ASYNC_REG = "TRUE" *) reg sync;
    reg [31:0] stable_count;
    always @(posedge clk) begin
        if (rst) begin meta <= 0; sync <= 0; value <= 0; stable_count <= 0; end
        else begin
            meta <= button;
            sync <= meta;
            if (sync == value) stable_count <= 0;
            else if (stable_count >= STABLE_CLKS - 1) begin
                value <= sync;
                stable_count <= 0;
            end else stable_count <= stable_count + 1'b1;
        end
    end
endmodule
