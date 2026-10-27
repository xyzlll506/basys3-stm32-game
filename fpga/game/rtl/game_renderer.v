`timescale 1ns / 1ps
`include "level.vh"
module game_renderer (
    input wire [9:0] x, input wire [9:0] y, input wire active,
    input wire [9:0] player_x, input wire [9:0] player_y,
    input wire [7:0] flags, input wire [15:0] deaths,
    input wire link_live,
    output reg [11:0] rgb
);
    function in_rect;
        input [9:0] px, py;
        input integer left, top, width, height;
        begin in_rect = px >= left && px < left + width && py >= top && py < top + height; end
    endfunction
    wire platform =
        in_rect(x,y,`LEVEL_PLATFORM_0_X,`LEVEL_PLATFORM_0_Y,`LEVEL_PLATFORM_0_W,`LEVEL_PLATFORM_0_H) ||
        in_rect(x,y,`LEVEL_PLATFORM_1_X,`LEVEL_PLATFORM_1_Y,`LEVEL_PLATFORM_1_W,`LEVEL_PLATFORM_1_H) ||
        in_rect(x,y,`LEVEL_PLATFORM_2_X,`LEVEL_PLATFORM_2_Y,`LEVEL_PLATFORM_2_W,`LEVEL_PLATFORM_2_H) ||
        in_rect(x,y,`LEVEL_PLATFORM_3_X,`LEVEL_PLATFORM_3_Y,`LEVEL_PLATFORM_3_W,`LEVEL_PLATFORM_3_H) ||
        in_rect(x,y,`LEVEL_PLATFORM_4_X,`LEVEL_PLATFORM_4_Y,`LEVEL_PLATFORM_4_W,`LEVEL_PLATFORM_4_H);
    wire hazard_box = in_rect(x,y,`LEVEL_HAZARD_0_X,`LEVEL_HAZARD_0_Y,`LEVEL_HAZARD_0_W,`LEVEL_HAZARD_0_H);
    wire goal = in_rect(x,y,`LEVEL_GOAL_X,`LEVEL_GOAL_Y,`LEVEL_GOAL_W,`LEVEL_GOAL_H);
    wire player = in_rect(x,y,player_x,player_y,`LEVEL_PLAYER_W,`LEVEL_PLAYER_H);
    wire [9:0] local_x = x - player_x;
    wire [9:0] local_y = y - player_y;
    wire [9:0] hazard_x = x - `LEVEL_HAZARD_0_X;
    wire [9:0] hazard_y = y - `LEVEL_HAZARD_0_Y;
    wire [4:0] spike_edge = hazard_x[3] ?
        ({1'b0,hazard_x[3:0]} - 5'd7) << 1 : (5'd7 - {1'b0,hazard_x[3:0]}) << 1;
    always @* begin
        // Sky gradient, clouds and a sparse background grid.
        rgb = y < 160 ? 12'h123 : y < 320 ? 12'h234 : 12'h345;
        if (x[6:0] == 0 || y[6:0] == 0) rgb = 12'h356;
        if (in_rect(x,y,65,80,80,12) || in_rect(x,y,350,65,100,12)) rgb = 12'h789;
        if (platform) rgb = (y[3:0] < 3) ? 12'h4DC : 12'h287;
        if (hazard_box) begin
            if (hazard_y >= spike_edge) rgb = 12'hF65;
        end
        if (goal) begin
            rgb = 12'hFC4;
            if (x > `LEVEL_GOAL_X + 4 && x < `LEVEL_GOAL_X + `LEVEL_GOAL_W - 4 &&
                y > `LEVEL_GOAL_Y + 4) rgb = 12'h462;
        end
        if (player) begin
            rgb = flags[2] ? 12'hF88 : 12'h5EF;
            if (local_y < 5) rgb = 12'hFEA;
            if ((local_x == 5 || local_x == 11) && local_y >= 6 && local_y <= 8) rgb = 12'h112;
            if (local_y >= `LEVEL_PLAYER_H - 4) rgb = 12'h136;
        end
        // HUD: connection square; eight low death-count bits; victory banner.
        if (in_rect(x,y,16,16,12,12)) rgb = link_live ? 12'h4F8 : 12'hF45;
        if (y >= 18 && y < 26 && x >= 40 && x < 104)
            rgb = deaths[(x-40) >> 3] ? 12'hF76 : 12'h567;
        if (flags[1] && in_rect(x,y,180,90,280,48)) begin
            rgb = 12'h4C8;
            if (in_rect(x,y,188,98,264,32)) rgb = 12'h173;
            // Large check mark inside the victory banner.
            if ((x >= 278 && x < 300 && y >= 110 && y < 118) ||
                (x >= 294 && x < 306 && y >= 118 && y < 126) ||
                (x >= 302 && x < 354 && y >= 102 && y < 110)) rgb = 12'hCFA;
        end
        if (!active) rgb = 0;
    end
endmodule
