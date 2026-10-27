`timescale 1ns / 1ps
`include "level.vh"
module tb_game;
    reg clk = 0;
    always #19.841270 clk = ~clk;
    reg rst = 1;
    reg link_reset = 0;
    reg raw_button = 0;
    wire filtered_button;
    reg button_done = 0;
    button_filter #(.STABLE_CLKS(4)) filter_test(clk,rst,raw_button,filtered_button);
    initial begin
        wait(!rst);
        @(negedge clk);raw_button=1;
        repeat(2) @(negedge clk);
        raw_button=0;
        repeat(8) @(negedge clk);
        if(filtered_button) $fatal(1,"Short button bounce was not rejected");
        raw_button=1;
        repeat(8) @(negedge clk);
        if(!filtered_button) $fatal(1,"Stable button press was not accepted");
        raw_button=0;
        repeat(8) @(negedge clk);
        if(filtered_button) $fatal(1,"Stable button release was not accepted");
        button_done=1;
    end
    wire [9:0] timing_x,timing_y;
    wire active,hs,vs,timing_frame;
    vga_timing timing(clk,rst,timing_x,timing_y,active,hs,vs,timing_frame);
    reg timing_done = 0;
    integer active_count,hs_count,vs_count,frame_count,cycles;
    initial begin
        wait (!rst);
        active_count=0;hs_count=0;vs_count=0;frame_count=0;
        for(cycles=0;cycles<420000;cycles=cycles+1) begin
            @(negedge clk);
            if(active) active_count=active_count+1;
            if(!hs) hs_count=hs_count+1;
            if(!vs) vs_count=vs_count+1;
            if(timing_frame) frame_count=frame_count+1;
            if(hs !== !(timing_x>=656 && timing_x<752)) $fatal(1,"HS window wrong");
            if(vs !== !(timing_y>=490 && timing_y<492)) $fatal(1,"VS window wrong");
        end
        if(active_count!=307200 || hs_count!=50400 || vs_count!=1600 || frame_count!=1)
            $fatal(1,"VGA frame totals wrong: active=%d hs=%d vs=%d frames=%d",active_count,hs_count,vs_count,frame_count);
        timing_done=1;
    end

    reg frame_tick=0;
    reg [3:0] buttons=4'b0101;
    reg rx=1;
    wire tx;
    wire [9:0] player_x,player_y;
    wire [7:0] flags;
    wire [15:0] deaths;
    wire link_live,good_toggle,error_toggle;
    game_link link(.clk(clk),.rst(rst|link_reset),.frame_tick(frame_tick),.buttons(buttons),
        .rx(rx),.tx(tx),.player_x(player_x),.player_y(player_y),.flags(flags),.deaths(deaths),
        .link_live(link_live),.good_toggle(good_toggle),.error_toggle(error_toggle));
    localparam real BIT_NS=8690.358;
    reg [7:0] captured[0:255];
    reg [7:0] decoded;
    integer capture_count=0;
    integer bit_no;
    initial forever begin
        @(negedge tx);
        #(BIT_NS/2);
        if(tx!==0) $fatal(1,"TX start bit wrong");
        for(bit_no=0;bit_no<8;bit_no=bit_no+1) begin #(BIT_NS);decoded[bit_no]=tx;end
        #(BIT_NS);
        if(tx!==1) $fatal(1,"TX stop bit wrong");
        captured[capture_count]=decoded;capture_count=capture_count+1;
    end
    task automatic pulse_frame;
        begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end
    endtask
    task automatic expect_request(input integer base,input [7:0] seq,input [3:0] input_bits);
        integer clocks;
        begin
            clocks=0;
            while(capture_count<base+4 && clocks<30000) begin @(posedge clk);clocks=clocks+1;end
            if(capture_count<base+4) $fatal(1,"Request timed out");
            if(captured[base]!==8'hA5 || captured[base+1]!==seq || captured[base+2]!=={4'b0,input_bits} ||
               captured[base+3] !== (8'hA5 ^ seq ^ {4'b0,input_bits}))
                $fatal(1,"Request bytes wrong at %d",base);
            #(BIT_NS);
        end
    endtask
    task automatic send_byte(input [7:0] value);
        integer i;
        begin
            rx=0;#(BIT_NS);
            for(i=0;i<8;i=i+1) begin rx=value[i];#(BIT_NS);end
            rx=1;#(BIT_NS);
        end
    endtask
    task automatic reply(input [7:0] seq,input [15:0] px,input [15:0] py,
                         input [7:0] state_flags,input [15:0] death_count,
                         input [7:0] reserved,input integer bad_xor);
        reg [7:0] checksum;
        begin
            checksum=8'h5A^seq^px[7:0]^px[15:8]^py[7:0]^py[15:8]^state_flags^
                     death_count[7:0]^death_count[15:8]^reserved;
            send_byte(8'h5A);send_byte(seq);send_byte(px[7:0]);send_byte(px[15:8]);
            send_byte(py[7:0]);send_byte(py[15:8]);send_byte(state_flags);
            send_byte(death_count[7:0]);send_byte(death_count[15:8]);
            send_byte(reserved);send_byte(0);send_byte(checksum ^ (bad_xor ? 8'h01 : 8'h00));
            repeat(10) @(negedge clk);
        end
    endtask
    task automatic unchanged;
        begin
            if(player_x!==123 || player_y!==321 || deaths!==2 || flags!==1)
                $fatal(1,"Bad/partial reply changed displayed state");
        end
    endtask

    reg [9:0] preview_x=0,preview_y=0;
    reg preview_active=1;
    wire [11:0] preview_rgb;
    game_renderer renderer(preview_x,preview_y,preview_active,
        10'd`LEVEL_SPAWN_X,10'd`LEVEL_SPAWN_Y,8'd0,16'd5,1'b1,preview_rgb);
    integer image_file,ix,iy;
    initial begin
        repeat(10) @(negedge clk);
        rst=0;
        repeat(5) @(negedge clk);
        if(link_live || player_x!=`LEVEL_SPAWN_X || player_y!=`LEVEL_SPAWN_Y)
            $fatal(1,"Initial state must show spawn and disconnected");
        pulse_frame();expect_request(0,0,4'b0101);
        reply(0,123,321,1,2,0,0);
        if(!link_live || player_x!=`LEVEL_SPAWN_X) $fatal(1,"Reply must wait until blanking commit");
        pulse_frame();expect_request(4,1,4'b0101);
        unchanged();
        reply(1,200,300,1,8,0,1); // incorrect XOR
        pulse_frame();expect_request(8,2,4'b0101);unchanged();
        reply(3,200,300,1,8,0,0); // incorrect sequence
        pulse_frame();expect_request(12,3,4'b0101);unchanged();
        reply(3,200,300,1,8,1,0); // reserved byte must be zero
        pulse_frame();expect_request(16,4,4'b0101);unchanged();
        reply(4,640,300,1,8,0,0); // out-of-screen coordinate
        pulse_frame();expect_request(20,5,4'b0101);unchanged();
        reply(5,200,300,8,8,0,0); // undefined flags
        pulse_frame();expect_request(24,6,4'b0101);unchanged();
        send_byte(8'h5A);send_byte(6); // incomplete response: full transaction timeout
        #8100000;
        buttons=4'b1000;
        pulse_frame();expect_request(28,7,4'b1000);unchanged();
        reply(7,165,90,2,16'hA55A,0,0); // header values are legal payload
        pulse_frame();expect_request(32,8,4'b1000);
        if(player_x!=165 || player_y!=90 || flags!=2 || deaths!=16'hA55A)
            $fatal(1,"Valid reply after timeout failed");
        rx=0;#(BIT_NS*12);rx=1;#(BIT_NS*2);
        if(link.active_transaction) $fatal(1,"Framing error did not cancel transaction");
        repeat(61) pulse_frame();
        if(link_live) $fatal(1,"Stale link did not expire after 60 frames");
        wait(timing_done && button_done);
        link_reset=1;repeat(5) @(negedge clk);link_reset=0;repeat(5) @(negedge clk);
        if(link_live || player_x!=`LEVEL_SPAWN_X) $fatal(1,"Link reset did not restore initial state");
        preview_active=0;#1;
        if(preview_rgb!==0) $fatal(1,"Blanking must force RGB black");
        preview_active=1;
        image_file=$fopen("preview.ppm","w");
        if(image_file==0) $fatal(1,"Cannot open HDL render preview");
        $fwrite(image_file,"P3\n640 480\n255\n");
        for(iy=0;iy<480;iy=iy+1) begin
            for(ix=0;ix<640;ix=ix+1) begin
                preview_x=ix;preview_y=iy;#1;
                $fwrite(image_file,"%0d %0d %0d ",preview_rgb[11:8]*17,preview_rgb[7:4]*17,preview_rgb[3:0]*17);
            end
            $fwrite(image_file,"\n");
        end
        $fclose(image_file);
        $display("PASS: game protocol, serial UART, pending frame commit, invalid replies, timeout/framing/reset recovery, stale link, button filtering, VGA totals/blanking, renderer preview");
        $finish;
    end
    initial begin #60000000;$fatal(1,"Global game simulation timeout");end
endmodule
