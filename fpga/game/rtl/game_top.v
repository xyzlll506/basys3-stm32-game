`timescale 1ns / 1ps
// Artix-7 MMCM: 100 / 5 * 31.5 = 630 MHz VCO; /25 = 25.2 MHz.
module game_top (
    input wire clk100, input wire btnC,
    input wire btnL, input wire btnR, input wire btnU, input wire btnD,
    input wire uart_rx, output wire uart_tx,
    output wire [3:0] vgaRed, output wire [3:0] vgaGreen, output wire [3:0] vgaBlue,
    output wire Hsync, output wire Vsync, output wire [15:0] led
);
    wire feedback_raw,feedback,pixel_raw,pixel_clk,locked;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(10.0),
        .DIVCLK_DIVIDE(5), .CLKFBOUT_MULT_F(31.5), .CLKOUT0_DIVIDE_F(25.0),
        .STARTUP_WAIT("FALSE")
    ) pixel_mmcm (
        .CLKIN1(clk100), .CLKFBIN(feedback), .RST(btnC), .PWRDWN(1'b0),
        .CLKFBOUT(feedback_raw), .CLKOUT0(pixel_raw), .LOCKED(locked),
        .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
    );
    BUFG feedback_buffer(.I(feedback_raw),.O(feedback));
    BUFG pixel_buffer(.I(pixel_raw),.O(pixel_clk));
    wire reset_request = btnC | ~locked;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;
    always @(posedge pixel_clk or posedge reset_request) begin
        if (reset_request) reset_pipe <= 2'b11;
        else reset_pipe <= {reset_pipe[0],1'b0};
    end
    game_core core (
        .clk(pixel_clk), .rst(reset_pipe[1]),
        .btnL(btnL),.btnR(btnR),.btnU(btnU),.btnD(btnD),
        .uart_rx(uart_rx),.uart_tx(uart_tx),
        .vgaRed(vgaRed),.vgaGreen(vgaGreen),.vgaBlue(vgaBlue),
        .Hsync(Hsync),.Vsync(Vsync),.led(led)
    );
endmodule
