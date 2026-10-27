`timescale 1ns / 1ps
module game_core #(
    parameter integer CLK_HZ = 25200000,
    parameter integer DEBOUNCE_CLKS = CLK_HZ / 200
) (
    input wire clk, input wire rst,
    input wire btnL, input wire btnR, input wire btnU, input wire btnD,
    input wire uart_rx, output wire uart_tx,
    output reg [3:0] vgaRed, output reg [3:0] vgaGreen, output reg [3:0] vgaBlue,
    output reg Hsync, output reg Vsync, output wire [15:0] led
);
    wire [3:0] buttons;
    button_filter #(.STABLE_CLKS(DEBOUNCE_CLKS)) left_button(clk,rst,btnL,buttons[0]);
    button_filter #(.STABLE_CLKS(DEBOUNCE_CLKS)) right_button(clk,rst,btnR,buttons[1]);
    button_filter #(.STABLE_CLKS(DEBOUNCE_CLKS)) jump_button(clk,rst,btnU,buttons[2]);
    button_filter #(.STABLE_CLKS(DEBOUNCE_CLKS)) restart_button(clk,rst,btnD,buttons[3]);
    wire [9:0] x,y;
    wire active, hs, vs, frame_tick;
    vga_timing timing(clk,rst,x,y,active,hs,vs,frame_tick);
    wire [9:0] player_x,player_y;
    wire [7:0] flags;
    wire [15:0] deaths;
    wire link_live,good_toggle,error_toggle;
    game_link #(.CLK_HZ(CLK_HZ)) link (
        .clk(clk), .rst(rst), .frame_tick(frame_tick), .buttons(buttons),
        .rx(uart_rx), .tx(uart_tx), .player_x(player_x), .player_y(player_y),
        .flags(flags), .deaths(deaths), .link_live(link_live),
        .good_toggle(good_toggle), .error_toggle(error_toggle)
    );
    wire [11:0] rgb;
    game_renderer renderer(x,y,active,player_x,player_y,flags,deaths,link_live,rgb);
    // Register RGB and sync together: one-pixel pipeline, no relative skew.
    always @(posedge clk) begin
        if (rst) begin vgaRed<=0; vgaGreen<=0; vgaBlue<=0; Hsync<=1; Vsync<=1; end
        else begin
            vgaRed <= rgb[11:8]; vgaGreen <= rgb[7:4]; vgaBlue <= rgb[3:0];
            Hsync <= hs; Vsync <= vs;
        end
    end
    reg [31:0] heartbeat_ticks;
    reg heartbeat;
    always @(posedge clk) begin
        if (rst) begin heartbeat_ticks<=0; heartbeat<=0; end
        else if (heartbeat_ticks >= CLK_HZ/2-1) begin heartbeat_ticks<=0; heartbeat<=~heartbeat; end
        else heartbeat_ticks<=heartbeat_ticks+1'b1;
    end
    assign led = {deaths[7:0], flags[1], buttons, error_toggle, good_toggle, heartbeat};
endmodule
