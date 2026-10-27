`timescale 1ns / 1ps
// 25.2 MHz pixel clock: 800 * 525 pixels/frame = exactly 60 Hz.
module vga_timing (
    input wire clk, input wire rst,
    output reg [9:0] x, output reg [9:0] y,
    output wire active, output wire hsync, output wire vsync,
    output wire frame_tick
);
    always @(posedge clk) begin
        if (rst) begin x <= 0; y <= 0; end
        else if (x == 799) begin
            x <= 0;
            if (y == 524) y <= 0;
            else y <= y + 1'b1;
        end else x <= x + 1'b1;
    end
    assign active = (x < 640) && (y < 480);
    assign hsync = !((x >= 656) && (x < 752));
    assign vsync = !((y >= 490) && (y < 492));
    // First pixel of vertical blank; state remains stable throughout active video.
    assign frame_tick = (x == 0) && (y == 480);
endmodule
