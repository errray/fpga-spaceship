`timescale 1ns / 1ps

module top(
	 input fire_mode1,
	 input gamelevel_top,
	 input ShootingModeSw,
	 input ates_tusu,
    input clk_50MHz,        // from DE1-SoC
    input reset,            // system reset
	 input ciguli,
	 input but1_top,
	 input but2_top,
	 output reg clk25,
    output hsync,           // VGA port on DE1-SoC
    output vsync,           // VGA port on DE1-SoC
    output [7:0] red,       // red to VGA port on DE1-SoC
    output [7:0] green,     // green to VGA port on DE1-SoC
    output [7:0] blue,       // blue to VGA port on DE1-SoC
	 output blank,
    output sync,
	 output [3:0] ledverisi,
	 output [6:0]hex0_top,
	 output [6:0]hex1_top,

	 output [6:0]hex2_top,
	 output [6:0]hex3_top

	 
    );
    
    wire w_video_on, w_p_tick;
    wire [9:0] w_x, w_y;
    reg [7:0] red_reg, green_reg, blue_reg;
    wire [7:0] red_next, green_next, blue_next;
	 
	  always @(posedge clk_50MHz) begin
        clk25 <= ~clk25;
    end
    
    vga_controller vc(
        .clk_50MHz(clk_50MHz), 
        .reset(reset), 
        .video_on(w_video_on), 
        .hsync(hsync), 
        .vsync(vsync), 
        .p_tick(w_p_tick), 
        .x(w_x), 
        .y(w_y)
    );
	 
	wire w1;
	wire w2;
	wire w3;
	wire w4;
	wire [3:0] w5;
	wire [3:0] w6;
	assign ledverisi=w6;
	
	wire w11;
	wire w12;
	wire w13;
	wire w14;
	wire fail_case_int;

	wire [8:0] score_led;
	
	 lfsr lfsr_top(
	.fire_mode_lfsr1(fire_mode1),

	.swcontrolalt(w4),
	.swcontrolsag(w2),
	.swcontrolust(w3),
	.swcontrolsol(w1),
	.swcontrolsolust(w11),
	.swcontrolsagust(w12),
	.swcontrolsolalt(w13),
	.swcontrolsagalt(w14),
	.countcase(w5),
	 .tetik_tusu(ates_tusu),
	.random_number(w6),
	 .clk(clk1hz),
	 .reset(reset),
	 .total_score(score_led),
	 .fail_case_input(fail_case_int)
	 
	 
	 
	 );
	 
	 
	 wire clk1hz;
	 clock_divider cd(
	 .clk_in(clk_50MHz),
	 .reset(reset),
	 .clk_out(clk1hz),
	 );
	
    pixel_generation_from_left pg(
			.gamelevel(gamelevel_top),
			.swsol(w1),
			.swsag(w2),
			.swust(w3),
			.swalt(w4),
			.ShootingModeIndicator(ShootingModeSw),
			.score_counter(score_led),
			.solust(w11),
			.swsagalt(w14),
			.swsagust(w12),
			.swsolalt(w13),
			.count(w5),
        .clk(clk_50MHz), 
        .ciguli(ciguli), 
        .video_on(w_video_on), 
        .x(w_x), 
        .y(w_y), 
        .red(red_next),
        .green(green_next),
        .blue(blue_next),
		  .but1(but1_top),
		  .but2(but2_top),
		  .fail_case_out(fail_case_int)

    );
	 		
			
			
	   seven_segment display (.number(score_led),
		.hex0(hex0_top), 
		.hex1(hex1_top), 
		.hex2(hex2_top), 
		.hex3(hex3_top)); 
	
	 
    
    always @(posedge clk_50MHz)
        if(w_p_tick) begin
            red_reg <= red_next;
            green_reg <= green_next;
            blue_reg <= blue_next;
        end
    
    assign red = red_reg;
    assign green = green_reg;
    assign blue = blue_reg;
	 
	 reg [9:0] a = 0;  // horizontal counter
    reg [9:0] b = 0;  // vertical counter
	 
	  always @(posedge clk25) begin
        if (a < 799)
            a <= a + 1;
        else
            a <= 0;
    end

    always @(posedge clk25) begin
        if (a == 799) begin
            if (b < 524)
                b <= b + 1;
            else
                b <= 0;
        end
    end

	 wire k;
    wire m;

    assign k = (a >= 640 && a < 799) ? 1 : 0;
    assign m = (b >= 480 && b < 525) ? 1 : 0;
    assign blank = ~(k | m);
    assign sync = 1'b0;
 
endmodule