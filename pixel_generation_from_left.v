`timescale 1ns / 1ps

module pixel_generation_from_left(
	 input ShootingModeIndicator,
	 input gamelevel,
    input swsol,
    input swsag,
    input swust,
    input swalt,
	 input [8:0] score_counter,
	 input solust,
	 input swsagalt,
	 input swsagust,
	 input swsolalt,
    input clk,                              // 50MHz from DE1-SoC
    input ciguli,                           // system reset
    input video_on,                         // from VGA controller
    input [9:0] x, y,                       // from VGA controller
    output reg [7:0] red,                   // to DAC, to VGA controller
    output reg [7:0] green,                 // to DAC, to VGA controller
    output reg [7:0] blue,                  // to DAC, to VGA controller
    input but1,
    input but2,
    output reg [3:0] count,
	 output [6:0] hex0, hex1, hex2, hex3,
	 output reg fail_case_out

);

    parameter SQUARE_SIZE = 20;             // square size
    parameter X_MAX = 639;                  // right border of display area
    parameter Y_MAX = 479;                  // bottom border of display area
    parameter CIRCLE_RGB = 8'hFF;           // red & green = yellow for circle
    parameter BG_RED = 8'h00;               // background red
    parameter BG_GREEN = 8'h00;             // background green
    parameter BG_BLUE = 8'h00;              // background blue
    parameter CIRCLE_RADIUS = 6;            // radius of the circle in pixels
    parameter CIRCLE_VELOCITY = 1;          // speed of the circle
    parameter TICK_DIVIDER_SLOW = 20;             // number of refresh ticks before moving the circle
	 parameter TICK_DIVIDER_FAST = 3;

    localparam CENTER_X = X_MAX / 2;        // center x coordinate
    localparam CENTER_Y = Y_MAX / 2;        // center y coordinate
    localparam SQUARE_LEFT = CENTER_X - (SQUARE_SIZE / 2);
    localparam SQUARE_RIGHT = CENTER_X + (SQUARE_SIZE / 2);
    localparam SQUARE_TOP = CENTER_Y - (SQUARE_SIZE / 2);
    localparam SQUARE_BOTTOM = CENTER_Y + (SQUARE_SIZE / 2);

    // create a 60Hz refresh tick at the start of vsync 
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0;  // y=481 is in the vertical blanking interval

    reg [4:0] tick_counter0;                 // counter to slow down the movement
    reg [4:0] tick_counter1; 
    reg [4:0] tick_counter2;
    reg [4:0] tick_counter3;
	 reg [4:0] tick_counter4;

	wire [4:0] TICK_DIVIDER;
	assign TICK_DIVIDER = gamelevel ? TICK_DIVIDER_SLOW : TICK_DIVIDER_FAST;


    // circle position
    reg [9:0] circle_x_reg, circle_y_reg;           // regs to track center position
    wire [9:0] circle_x_next;                       // buffer wires for next position //soldaki

    reg [9:0] circle_x1_reg, circle_y1_reg;         // regs to track center position
    wire [9:0] circle_x1_next;                      // buffer wires for next position //sağdaki

    reg [9:0] circle_y2_reg, circle_x2_reg;         // regs to track center position
    wire [9:0] circle_y2_next;                      // buffer wires for next position //tepedeki

    reg [9:0] circle_y3_reg, circle_x3_reg;         // regs to track center position
    wire [9:0] circle_y3_next;                      // buffer wires for next position //alttaki
	 
	 
    // taret basi
    reg [3:0] countup;
    reg [3:0] countdown;

    always @(posedge but1) begin
        countup <= countup + 1;
    end

    always @(posedge but2) begin
        countdown <= countdown + 1;
    end

    always @(countup or countdown) begin
        count <= countup - countdown;
    end

    reg in_rocket_tip;

    always @(posedge but1 or posedge but2 ) begin
        case(count)
            0:    in_rocket_tip = (x >= 320 - 2 && x <= 320 + 2 && y >= 240 - 20 && y < 240);
            10:   in_rocket_tip = (x - y <= 320 - 240 + 3 && x - y >= 320 - 240 - 3 && x + y <= 320 + 240 + 30 && x + y >= 320 + 240); // sağ alt
            2:    in_rocket_tip = (x - y <= 320 - 240 + 3 && x - y >= 320 - 240 - 3 && x + y >= 320 + 240 - 30 && x + y <= 320 + 240); // sol üst
            14:   in_rocket_tip = (x - y <= 320 - 240 + 30 && x - y >= 320 - 240  && x + y >= 320 + 240 - 3 && x + y <= 320 + 240 + 3); // sağ üst
            6:    in_rocket_tip = (x - y >= 320 - 240 - 30 && x - y <= 320 - 240  && x + y >= 320 + 240 - 3 && x + y <= 320 + 240 + 3); // sol alt
            4:    in_rocket_tip = (y >= 240 - 2 && y <= 240 + 2 && x >= 320 - 20 & x < 320);
            8:    in_rocket_tip = (x >= 320 - 2 && x <= 320 + 2 && y <= 240 + 20 && y > 240);
            12:   in_rocket_tip = (y >= 240 - 2 && y <= 240 + 2 && x <= 320 + 20 && x > 320);
            15:   in_rocket_tip = (x - 2 * y <= 320 - 2 * 240 + 50 && x - 2 * y >= 320 - 2 * 240  && 2 * x + y >= 2 * 320 + 240 - 5 && 2 * x + y <= 2 * 320 + 240 + 5);  // 22.5
            13:   in_rocket_tip = (x + 2 * y >= 320 + 2 * 240 - 5 && x + 2 * y <= 320 + 2 * 240 + 5  && 2 * x - y >= 2 * 320 - 240  && 2 * x - y <= 2 * 320 - 240 + 50);
            11:   in_rocket_tip = (x - 2 * y >= 320 - 2 * 240 - 5 && x - 2 * y <= 320 - 2 * 240 + 5  && 2 * x + y >= 2 * 320 + 240 && 2 * x + y <= 2 * 320 + 240 + 50);  // 112.5
            9:    in_rocket_tip = (2 * x - y >= 2 * 320 - 240 - 5 && 2 * x - y <= 2 * 320 - 240 + 5  && x + 2 * y >= 320 + 2 * 240 && x + 2 * y <= 320 + 2 * 240 + 50);  // 157.5
            7:    in_rocket_tip = (x - 2 * y >= 320 - 2 * 240 - 50 && x - 2 * y <= 320 - 2 * 240  && 2 * x + y >= 2 * 320 + 240 - 5 && 2 * x + y <= 2 * 320 + 240 + 5);  // 202.5
            5:    in_rocket_tip = (x + 2 * y >= 320 + 2 * 240 - 5 && x + 2 * y <= 320 + 2 * 240 + 5  && 2 * x - y >= 2 * 320 - 240 - 50 && 2 * x - y <= 2 * 320 - 240);
            3:    in_rocket_tip = (x - 2 * y >= 320 - 2 * 240 - 5 && x - 2 * y <= 320 - 2 * 240 + 5  && 2 * x + y >= 2 * 320 + 240 - 50 && 2 * x + y <= 2 * 320 + 240);  // 292.5
            1:    in_rocket_tip = (2 * x - y >= 2 * 320 - 240 - 5 && 2 * x - y <= 2 * 320 - 240 + 5  && x + 2 * y >= 320 + 2 * 240 - 50 && x + 2 * y <= 320 + 2 * 240);  // -22.5
        endcase
    end

    wire rocket_body;
    assign rocket_body = ((x - 320) * (x - 320) + (y - 240) * (y - 240)) <= 100;

	  // Register control for sagustgelen
   
	wire fail_case;
	assign fail_case = (SQUARE_LEFT - circle_x_reg <= 10 || SQUARE_RIGHT - circle_x_reg <= 10 || SQUARE_TOP - circle_y2_reg <= 10 || SQUARE_BOTTOM - circle_y3_reg <= 10|| (plus_x4_reg == CENTER_X && plus_y4_reg == CENTER_Y) || (plus_x5_reg == CENTER_X && plus_y5_reg == CENTER_Y) || (plus_x6_reg == CENTER_X && plus_y6_reg == CENTER_Y) || (plus_x7_reg == CENTER_X && plus_y7_reg == CENTER_Y))? 1:0;
	always@(clk)begin
		fail_case_out <= fail_case;
	end
	 	
    //sagustgelenson

    // Register control for soldangelen
    always @(posedge clk or posedge ciguli) begin
        if (ciguli) begin
            circle_x_reg <= 0;  // Initial x position set to 0
            circle_y_reg <= 240;  // Initial y position set to 240 so that we test if object goes in x direction 
            tick_counter0 <= 0;
        end else if (swsol) begin
            if (refresh_tick) begin
                if (tick_counter0 < TICK_DIVIDER - 1)
                    tick_counter0 <= tick_counter0 + 1;
                else begin
                    tick_counter0 <= 0;
                    circle_x_reg <= circle_x_next;  // Update circle position
                end
            end
        end else begin
            circle_x_reg <= 0;  // Initial x position set to 0
            circle_y_reg <= 240;  // Initial y position set to 240 so that we test if object goes in x direction 
            tick_counter0 <= 0;
        end
    end

    // circle status signal
    reg circle_on;
    always @(*) begin
        if (swsol == 1) begin
            if (ciguli) begin
                circle_on = 1;  // Initialize circle_on to 1
            end else if (SQUARE_LEFT - circle_x_reg <= 10) begin
                circle_on = 0;  // Stop the circle when it reaches close to the square's left boundary
            end else begin 
                circle_on = 1; 
            end
        end else begin
            circle_on = 0;  // Stop the circle when it reaches close to the square's left boundary
        end
    end
    //soldangelenson

    // Register control for sagdangelen
    always @(posedge clk or posedge ciguli) begin
        if (ciguli) begin
            circle_x1_reg <= 640;  // Initial x position set to 640
            circle_y1_reg <= 240;  // Initial y position set to 240 so that we test if object goes in x direction 
            tick_counter1 <= 0;
        end else if (swsag) begin
            if (refresh_tick) begin
                if (tick_counter1 < TICK_DIVIDER - 1) begin
                    tick_counter1 <= tick_counter1 + 1;
                end else begin
                    tick_counter1 <= 0;
                    circle_x1_reg <= circle_x1_next;  // Update circle position
                end
            end
        end else begin
            circle_x1_reg <= 640;  // Initial x position set to 640
            circle_y1_reg <= 240;  // Initial y position set to 240 so that we test if object goes in x direction 
            tick_counter1 <= 0;
        end
    end

    // circle status signal
    reg circle1_on;
    always @(*) begin
        if (swsag == 1) begin
            if (ciguli) begin
                circle1_on = 1;  // Initialize circle_on to 1
            end else if (SQUARE_RIGHT - circle_x1_reg <= 10) begin
                circle1_on = 0;  // Stop the circle when it reaches close to the square's right boundary
            end else begin 
                circle1_on = 1; 
            end
        end else begin
            circle1_on = 0;  // Stop the circle when it reaches close to the square's right boundary
        end
    end
    //sagdangelenson

    // Register control for tepedengelen
    always @(posedge clk or posedge ciguli) begin
        if (ciguli) begin
            circle_y2_reg <= 0;  
            circle_x2_reg <= 320; 
            tick_counter2 <= 0;
        end else if (swust) begin
            if (refresh_tick) begin
                if (tick_counter2 < TICK_DIVIDER - 1) begin
                    tick_counter2 <= tick_counter2 + 1;
                end else begin
                    tick_counter2 <= 0;
                    circle_y2_reg <= circle_y2_next;  // Update circle position
                end
            end
        end else begin
            circle_y2_reg <= 0;  // Initial y position set to 0
            circle_x2_reg <= 320;  // Initial x position set to 320 so that we test if object goes in y direction 
            tick_counter2 <= 0;
        end
    end

    // circle status signal
    reg circle2_on;
    always @(*) begin
        if (swust == 1) begin
            if (ciguli) begin
                circle2_on = 1;  // Initialize circle_on to 1
            end else if (SQUARE_TOP - circle_y2_reg <= 10) begin
                circle2_on = 0;  // Stop the circle when it reaches close to the square's top boundary
            end else begin 
                circle2_on = 1; 
            end
        end else begin
            circle2_on = 0;  // Stop the circle when it reaches close to the square's top boundary
        end
    end
    //tepedengelenson

    // Register control for alttangelen
    always @(posedge clk or posedge ciguli) begin
        if (ciguli) begin
            circle_y3_reg <= 480;  
            circle_x3_reg <= 320; 
            tick_counter3 <= 0;
        end else if (swalt) begin
            if (refresh_tick) begin
                if (tick_counter3 < TICK_DIVIDER - 1) begin
                    tick_counter3 <= tick_counter3 + 1;
                end else begin
                    tick_counter3 <= 0;
                    circle_y3_reg <= circle_y3_next;  // Update circle position
                end
            end
        end else begin
            circle_y3_reg <= 480;  // Initial y position set to 480
            circle_x3_reg <= 320;  // Initial x position set to 320 so that we test if object goes in y direction 
            tick_counter3 <= 0;
        end
    end

    // circle status signal
    reg circle3_on;
    always @(*) begin
        if (swalt == 1) begin
            if (ciguli) begin
                circle3_on = 1;  // Initialize circle_on to 1
            end else if (SQUARE_BOTTOM - circle_y3_reg <= 10) begin
                circle3_on = 0;  // Stop the circle when it reaches close to the square's bottom boundary
            end else begin 
                circle3_on = 1; 
            end
        end else begin
            circle3_on = 0;  // Stop the circle when it reaches close to the square's bottom boundary
        end
    end
    //alltangelenson

    // object direction and velocity 
    wire [9:0] x_step;
    assign x_step = circle_on ? CIRCLE_VELOCITY : 0;  // Changed to consider circle_on
    assign circle_x_next = circle_x_reg + x_step;     // Changed to use x_step

    wire [9:0] x1_step;
    assign x1_step = circle1_on ? CIRCLE_VELOCITY : 0;  
    assign circle_x1_next = circle_x1_reg - x1_step;     

    wire [9:0] y2_step;
    assign y2_step = circle2_on ? CIRCLE_VELOCITY : 0;  
    assign circle_y2_next = circle_y2_reg + y2_step; 

    wire [9:0] y3_step;
    assign y3_step = circle3_on ? CIRCLE_VELOCITY : 0;  
    assign circle_y3_next = circle_y3_reg - y3_step;   
		 




localparam SLOW_DIV = 2;  // Slow down factor
localparam PLUS_WIDTH = 10; // Width of the plus sign

// Plus sign position (center position)
reg [9:0] plus_x4_reg, plus_y4_reg;           // regs to track center position
reg [9:0] plus_x4_next, plus_y4_next;         // buffer regs

reg [9:0] x4_delta_reg, y4_delta_reg;     // track plus sign speed
reg [9:0] x4_delta_next, y4_delta_next;   // buffer regs    

// Slower tick generation
reg [1:0] slow_counter;
wire slow_tick;

// Plus sign status signal
reg plus4_on;

// Register control
always @(posedge clk or posedge ciguli)
    if (ciguli) begin
        plus_x4_reg <= 80;
        plus_y4_reg <= 0;
        x4_delta_reg <= 80;
        y4_delta_reg <= 0;
        slow_counter <= 0;
    end
    else begin
        if (slow_counter == SLOW_DIV - 1) begin
            slow_counter <= 0;
        end else begin
            slow_counter <= slow_counter + 1;
        end
        if (slow_tick) begin
            plus_x4_reg <= plus_x4_next;
            plus_y4_reg <= plus_y4_next;
            x4_delta_reg <= x4_delta_next;
            y4_delta_reg <= y4_delta_next;
        end
    end

assign slow_tick = (slow_counter == SLOW_DIV - 1);

// New plus sign velocity and status signal
always @* begin
    if (solust == 1) begin
        x4_delta_next = x4_delta_reg;
        y4_delta_next = y4_delta_reg;

        if (plus_x4_reg < CENTER_X)
            x4_delta_next = 1;   // move right towards center
        else if (plus_x4_reg > CENTER_X)
            x4_delta_next = -1;  // move left towards center
        else
            x4_delta_next = 0;   // stop moving in x direction if at center

        if (plus_y4_reg < CENTER_Y)
            y4_delta_next = 1;   // move down towards center
        else if (plus_y4_reg > CENTER_Y)
            y4_delta_next = -1;  // move up towards center
        else
            y4_delta_next = 0;   // stop moving in y direction if at center

        plus4_on = ((x >= (plus_x4_reg - PLUS_WIDTH) && x <= (plus_x4_reg + PLUS_WIDTH) && y == plus_y4_reg) ||
                    (y >= (plus_y4_reg - PLUS_WIDTH) && y <= (plus_y4_reg + PLUS_WIDTH) && x == plus_x4_reg)) &&
                    !(plus_x4_reg == CENTER_X && plus_y4_reg == CENTER_Y);

        // Update plus sign position
        if (refresh_tick && slow_tick && !(plus_x4_reg == CENTER_X && plus_y4_reg == CENTER_Y)) begin
            plus_x4_next = plus_x4_reg + x4_delta_reg;
            plus_y4_next = plus_y4_reg + y4_delta_reg;
        end else begin
            plus_x4_next = plus_x4_reg;
            plus_y4_next = plus_y4_reg;
        end
    end else begin
        plus4_on = 0;  // Set plus4_on to 0 when solust is not 1
        // Reset to initial conditions
        x4_delta_next = 80;
        y4_delta_next = 0;
        plus_x4_next = 80;
        plus_y4_next = 0;
    end
end
// sagust 
localparam SLOW_DIV_1 = 2;  // Slow down factor
localparam PLUS_WIDTH_1 = 10; // Width of the plus sign

// Plus sign position (center position)
reg [9:0] plus_x5_reg, plus_y5_reg;           // regs to track center position
reg [9:0] plus_x5_next, plus_y5_next;         // buffer regs

reg [9:0] x5_delta_reg, y5_delta_reg;     // track plus sign speed
reg [9:0] x5_delta_next, y5_delta_next;   // buffer regs    

// Slower tick generation
reg [1:0] slow_counter_1;
wire slow_tick_1;

// Plus sign status signal
reg plus5_on;

// Register control
always @(posedge clk or posedge ciguli)
    if (ciguli) begin
        plus_x5_reg <= 560;
        plus_y5_reg <= 0;
        x5_delta_reg <= -80;
        y5_delta_reg <= 0;
        slow_counter_1 <= 0;
    end
    else begin
        if (slow_counter_1 == SLOW_DIV_1 - 1) begin
            slow_counter_1 <= 0;
        end else begin
            slow_counter_1 <= slow_counter_1 + 1;
        end
        if (slow_tick_1) begin
            plus_x5_reg <= plus_x5_next;
            plus_y5_reg <= plus_y5_next;
            x5_delta_reg <= x5_delta_next;
            y5_delta_reg <= y5_delta_next;
        end
    end

assign slow_tick_1 = (slow_counter_1 == SLOW_DIV_1 - 1);
 // New plus sign velocity and status signal
always @* begin
    if (swsagust == 1) begin
        x5_delta_next = x5_delta_reg;
        y5_delta_next = y5_delta_reg;

        if (plus_x5_reg < CENTER_X)
            x5_delta_next = 1;   // move right towards center
        else if (plus_x5_reg > CENTER_X)
            x5_delta_next = -1;  // move left towards center
        else
            x5_delta_next = 0;   // stop moving in x direction if at center

        if (plus_y5_reg < CENTER_Y)
            y5_delta_next = 1;   // move down towards center
        else if (plus_y5_reg > CENTER_Y)
            y5_delta_next = -1;  // move up towards center
        else
            y5_delta_next = 0;   // stop moving in y direction if at center

        plus5_on = ((x >= (plus_x5_reg - PLUS_WIDTH) && x <= (plus_x5_reg + PLUS_WIDTH) && y == plus_y5_reg) ||
                    (y >= (plus_y5_reg - PLUS_WIDTH) && y <= (plus_y5_reg + PLUS_WIDTH) && x == plus_x5_reg)) &&
                    !(plus_x5_reg == CENTER_X && plus_y5_reg == CENTER_Y);

        // Update plus sign position
        if (refresh_tick && slow_tick_1 && !(plus_x5_reg == CENTER_X && plus_y5_reg == CENTER_Y)) begin
            plus_x5_next = plus_x5_reg + x5_delta_reg;
            plus_y5_next = plus_y5_reg + y5_delta_reg;
        end else begin
            plus_x5_next = plus_x5_reg;
            plus_y5_next = plus_y5_reg;
        end
    end else begin
        plus5_on = 0;  // Set plus4_on to 0 when solust is not 1
        // Reset to initial conditions
        x5_delta_next = -1;
        y5_delta_next = 1;
        plus_x5_next = 560;
        plus_y5_next = 0;
    end
end

//sagalt
localparam SLOW_DIV_2 = 2;  // Slow down factor
localparam RECT_WIDTH = 9;  // Width of the rectangle
localparam RECT_HEIGHT = 4; // Height of the rectangle

// Plus sign position (center position)
reg [9:0] plus_x6_reg, plus_y6_reg;           // regs to track center position
reg [9:0] plus_x6_next, plus_y6_next;         // buffer regs

reg [9:0] x6_delta_reg, y6_delta_reg;     // track plus sign speed
reg [9:0] x6_delta_next, y6_delta_next;   // buffer regs    

// Slower tick generation
reg [1:0] slow_counter_2;
wire slow_tick_2;

// Plus sign status signal
reg plus6_on;

// Register control
always @(posedge clk or posedge ciguli)
    if (ciguli) begin
        plus_x6_reg <= 560;
        plus_y6_reg <= 480;
        x6_delta_reg <= 0;
        y6_delta_reg <= -40;
        slow_counter_2 <= 0;
    end
    else begin
        if (slow_counter_2 == SLOW_DIV_2 - 1) begin
            slow_counter_2 <= 0;
        end else begin
            slow_counter_2 <= slow_counter_2 + 1;
        end
        if (slow_tick_2) begin
            plus_x6_reg <= plus_x6_next;
            plus_y6_reg <= plus_y6_next;
            x6_delta_reg <= x6_delta_next;
            y6_delta_reg <= y6_delta_next;
        end
    end

assign slow_tick_2 = (slow_counter_2 == SLOW_DIV_2 - 1);
 // New plus sign velocity and status signal
always @* begin
    if (swsagalt == 1) begin
        x6_delta_next = x6_delta_reg;
        y6_delta_next = y6_delta_reg;

        if (plus_x6_reg < CENTER_X)
            x6_delta_next = 1;   // move right towards center
        else if (plus_x6_reg > CENTER_X)
            x6_delta_next = -1;  // move left towards center
        else
            x6_delta_next = 0;   // stop moving in x direction if at center

        if (plus_y6_reg < CENTER_Y)
            y6_delta_next = 1;   // move down towards center
        else if (plus_y6_reg > CENTER_Y)
            y6_delta_next = -1;  // move up towards center
        else
            y6_delta_next = 0;   // stop moving in y direction if at center

        plus6_on = ((x >= (plus_x6_reg - RECT_WIDTH) && x <= (plus_x6_reg + RECT_WIDTH) && 
                     y >= (plus_y6_reg - RECT_HEIGHT) && y <= (plus_y6_reg + RECT_HEIGHT)) &&
                     !(plus_x6_reg == CENTER_X && plus_y6_reg == CENTER_Y));

        // Update plus sign position
        if (refresh_tick && slow_tick_2 && !(plus_x6_reg == CENTER_X && plus_y6_reg == CENTER_Y)) begin
            plus_x6_next = plus_x6_reg + x6_delta_reg;
            plus_y6_next = plus_y6_reg + y6_delta_reg;
        end else begin
            plus_x6_next = plus_x6_reg;
            plus_y6_next = plus_y6_reg;
        end
    end else begin
        plus6_on = 0;  // Set plus4_on to 0 when solust is not 1
        // Reset to initial conditions
        x6_delta_next = -1;
        y6_delta_next = -1;
        plus_x6_next = 560;
        plus_y6_next = 480;
    end
end

//sagaltson

//solalt

localparam SLOW_DIV_3 = 2;  // Slow down factor
localparam PLUS_WIDTH_3 = 6; // Width of the plus sign

// Plus sign position (center position)
reg [9:0] plus_x7_reg, plus_y7_reg;           // regs to track center position
reg [9:0] plus_x7_next, plus_y7_next;         // buffer regs

reg [9:0] x7_delta_reg, y7_delta_reg;     // track plus sign speed
reg [9:0] x7_delta_next, y7_delta_next;   // buffer regs    

// Slower tick generation
reg [1:0] slow_counter_3;
wire slow_tick_3;

// Plus sign status signal
reg plus7_on;

// Register control
always @(posedge clk or posedge ciguli)
    if (ciguli) begin
        plus_x7_reg <= 80;
        plus_y7_reg <= 480;
        x7_delta_reg <= 0;
        y7_delta_reg <= -40;
        slow_counter_3 <= 0;
    end
    else begin
        if (slow_counter_3 == SLOW_DIV_3 - 1) begin
            slow_counter_3 <= 0;
        end else begin
            slow_counter_3 <= slow_counter_3 + 1;
        end
        if (slow_tick_3) begin
            plus_x7_reg <= plus_x7_next;
            plus_y7_reg <= plus_y7_next;
            x7_delta_reg <= x7_delta_next;
            y7_delta_reg <= y7_delta_next;
        end
    end

assign slow_tick_3 = (slow_counter_3 == SLOW_DIV_3 - 1);
 // New plus sign velocity and status signal
always @* begin
    if (swsolalt == 1) begin
        x7_delta_next = x7_delta_reg;
        y7_delta_next = y7_delta_reg;

        if (plus_x7_reg < CENTER_X)
            x7_delta_next = 1;   // move right towards center
        else if (plus_x7_reg > CENTER_X)
            x7_delta_next = -1;  // move left towards center
        else
            x7_delta_next = 0;   // stop moving in x direction if at center

        if (plus_y7_reg < CENTER_Y)
            y7_delta_next = 1;   // move down towards center
        else if (plus_y7_reg > CENTER_Y)
            y7_delta_next = -1;  // move up towards center
        else
            y7_delta_next = 0;   // stop moving in y direction if at center

plus7_on = ((x >= (plus_x7_reg - PLUS_WIDTH_3) && x <= (plus_x7_reg + PLUS_WIDTH_3)) &&
            (y >= (plus_y7_reg - PLUS_WIDTH_3) && y <= (plus_y7_reg + PLUS_WIDTH_3))) &&
            !(plus_x7_reg == CENTER_X && plus_y7_reg == CENTER_Y);


        // Update plus sign position
        if (refresh_tick && slow_tick_3 && !(plus_x7_reg == CENTER_X && plus_y7_reg == CENTER_Y)) begin
            plus_x7_next = plus_x7_reg + x7_delta_reg;
            plus_y7_next = plus_y7_reg + y7_delta_reg;
        end else begin
            plus_x7_next = plus_x7_reg;
            plus_y7_next = plus_y7_reg;
        end
    end else begin
        plus7_on = 0;  // Set plus4_on to 0 when solust is not 1
        // Reset to initial conditions
        x7_delta_next = 1;
        y7_delta_next = -1;
        plus_x7_next = 80;
        plus_y7_next = 480;
    end
end


//solaltson


////////////////////////////////////////////////////////////////////////////////////// Fixed SCORE= Generate

////////////////////////////////////////////////////////////////////////////////////// LETTER S
wire [4:0] Letter_S;
assign Letter_S[0] = (x >= 509-500 && x <= 520-500 && y >= 459 && y <= 461);
assign Letter_S[1] = (x >= 509-500 && x <= 520-500 && y >= 468 && y <= 470);
assign Letter_S[2] = (x >= 509-500 && x <= 520-500 && y >= 477 && y <= 479);
assign Letter_S[3] = (x >= 509-500 && x <= 511-500 && y >= 462 && y <= 467);
assign Letter_S[4] = (x >= 518-500 && x <= 520-500 && y >= 471 && y <= 476);
////////////////////////////////////////////////////////////////////////////////////// END LETTER S

////////////////////////////////////////////////////////////////////////////////////// LETTER C
wire [2:0] Letter_C;
assign Letter_C[0] = (x >= 522-500 && x <= 533-500 && y >= 459 && y <= 461);
assign Letter_C[1] = (x >= 522-500 && x <= 533-500 && y >= 477 && y <= 479);
assign Letter_C[2] = (x >= 522-500 && x <= 524-500 && y >= 462 && y <= 476);
////////////////////////////////////////////////////////////////////////////////////// END LETTER C

////////////////////////////////////////////////////////////////////////////////////// LETTER O
wire [3:0] Letter_O;
assign Letter_O[0] = (x >= 535-500 && x <= 546-500 && y >= 459 && y <= 461);
assign Letter_O[1] = (x >= 535-500 && x <= 546-500 && y >= 477 && y <= 479);
assign Letter_O[2] = (x >= 535-500 && x <= 537-500 && y >= 462 && y <= 476);
assign Letter_O[3] = (x >= 544-500 && x <= 546-500 && y >= 462 && y <= 476);
////////////////////////////////////////////////////////////////////////////////////// END LETTER O

////////////////////////////////////////////////////////////////////////////////////// LETTER R
wire [7:0] Letter_R;
assign Letter_R[0] = (x >= 548-500 && x <= 559-500 && y >= 459 && y <= 461);
assign Letter_R[1] = (x >= 548-500 && x <= 559-500 && y >= 468 && y <= 470);
assign Letter_R[2] = (x >= 548-500 && x <= 550-500 && y >= 462 && y <= 467);
assign Letter_R[3] = (x >= 548-500 && x <= 550-500 && y >= 471 && y <= 479);
assign Letter_R[4] = (x >= 557-500 && x <= 559-500 && y >= 462 && y <= 467);
assign Letter_R[5] = (x >= 551-500 && x <= 553-500 && y >= 471 && y <= 473);
assign Letter_R[6] = (x >= 554-500 && x <= 556-500 && y >= 474 && y <= 476);
assign Letter_R[7] = (x >= 557-500 && x <= 559-500 && y >= 477 && y <= 479);
////////////////////////////////////////////////////////////////////////////////////// END LETTER R

////////////////////////////////////////////////////////////////////////////////////// LETTER E
wire [4:0] Letter_E;
assign Letter_E[0] = (x >= 561-500 && x <= 572-500 && y >= 459 && y <= 461);
assign Letter_E[1] = (x >= 561-500 && x <= 572-500 && y >= 468 && y <= 470);
assign Letter_E[2] = (x >= 561-500 && x <= 572-500 && y >= 477 && y <= 479);
assign Letter_E[3] = (x >= 561-500 && x <= 563-500 && y >= 462 && y <= 467);
assign Letter_E[4] = (x >= 561-500 && x <= 563-500 && y >= 471 && y <= 476);
////////////////////////////////////////////////////////////////////////////////////// END LETTER E

////////////////////////////////////////////////////////////////////////////////////// SIGN =
wire [1:0] Sign_Equal;
assign Sign_Equal[0] = (x >= 574-500 && x <= 585-500 && y >= 465 && y <= 467);
assign Sign_Equal[1] = (x >= 574-500 && x <= 585-500 && y >= 471 && y <= 473);
////////////////////////////////////////////////////////////////////////////////////// END SIGN =

////////////////////////////////////////////////////////////////////////////////////// End Fixed SCORE= Generate



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// number generate
reg [6:0] bit_0, bit_1, bit_2, bit_3;
wire [6:0] number_0_bit_0, number_1_bit_0, number_2_bit_0, number_3_bit_0, number_4_bit_0, number_5_bit_0, number_6_bit_0, number_7_bit_0, number_8_bit_0, number_9_bit_0;
wire [6:0] number_0_bit_1, number_1_bit_1, number_2_bit_1, number_3_bit_1, number_4_bit_1, number_5_bit_1, number_6_bit_1, number_7_bit_1, number_8_bit_1, number_9_bit_1;
wire [6:0] number_0_bit_2, number_1_bit_2, number_2_bit_2, number_3_bit_2, number_4_bit_2, number_5_bit_2, number_6_bit_2, number_7_bit_2, number_8_bit_2, number_9_bit_2;
wire [6:0] number_0_bit_3, number_1_bit_3, number_2_bit_3, number_3_bit_3, number_4_bit_3, number_5_bit_3, number_6_bit_3, number_7_bit_3, number_8_bit_3, number_9_bit_3;

// wire number_0_bit_0;
assign number_0_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_0_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_0_bit_0[2] = (x >= 626-500 && x <= 628-500 && y >= 462 && y <= 476);
assign number_0_bit_0[3] = (x >= 635-500 && x <= 637-500 && y >= 462 && y <= 476);

// wire number_1_bit_0;
assign number_1_bit_0[0] = (x >= 635-500 && x <= 637-500 && y >= 459 && y <= 479);
	
// wire number_2_bit_0;
assign number_2_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_2_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 468 && y <= 470);
assign number_2_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_2_bit_0[3] = (x >= 626-500 && x <= 628-500 && y >= 471 && y <= 476);
assign number_2_bit_0[4] = (x >= 635-500 && x <= 637-500 && y >= 462 && y <= 467);

// wire number_3_bit_0;
assign number_3_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_3_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 468 && y <= 470);
assign number_3_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_3_bit_0[3] = (x >= 635-500 && x <= 637-500 && y >= 471 && y <= 476);
assign number_3_bit_0[4] = (x >= 635-500 && x <= 637-500 && y >= 462 && y <= 467);

// wire number_4_bit_0;
assign number_4_bit_0[0] = (x >= 626-500 && x <= 628-500 && y >= 459 && y <= 470);
assign number_4_bit_0[1] = (x >= 635-500 && x <= 637-500 && y >= 459 && y <= 479);
assign number_4_bit_0[2] = (x >= 629-500 && x <= 634-500 && y >= 468 && y <= 470);

// wire number_5_bit_0;
assign number_5_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_5_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 468 && y <= 470);
assign number_5_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_5_bit_0[3] = (x >= 626-500 && x <= 628-500 && y >= 462 && y <= 467);
assign number_5_bit_0[4] = (x >= 635-500 && x <= 637-500 && y >= 471 && y <= 476);

// wire number_6_bit_0;
assign number_6_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_6_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 468 && y <= 470);
assign number_6_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_6_bit_0[3] = (x >= 626-500 && x <= 628-500 && y >= 462 && y <= 467);
assign number_6_bit_0[4] = (x >= 626-500 && x <= 628-500 && y >= 471 && y <= 476);
assign number_6_bit_0[5] = (x >= 635-500 && x <= 637-500 && y >= 471 && y <= 476);

// wire number_7_bit_0;
assign number_7_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_7_bit_0[1] = (x >= 635-500 && x <= 637-500 && y >= 462 && y <= 479);

// wire number_8_bit_0;
assign number_8_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_8_bit_0[1] = (x >= 626 -500&& x <= 637-500 && y >= 468 && y <= 470);
assign number_8_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_8_bit_0[3] = (x >= 626-500 && x <= 628-500 && y >= 462 && y <= 467);
assign number_8_bit_0[4] = (x >= 626-500 && x <= 628-500 && y >= 471 && y <= 476);
assign number_8_bit_0[5] = (x >= 635-500 && x <= 637-500 && y >= 462 && y <= 467);
assign number_8_bit_0[6] = (x >= 635-500 && x <= 637-500 && y >= 471 && y <= 476);

// wire number_9_bit_0;
assign number_9_bit_0[0] = (x >= 626-500 && x <= 637-500 && y >= 459 && y <= 461);
assign number_9_bit_0[1] = (x >= 626-500 && x <= 637-500 && y >= 468 && y <= 470);
assign number_9_bit_0[2] = (x >= 626-500 && x <= 637-500 && y >= 477 && y <= 479);
assign number_9_bit_0[3] = (x >= 626-500 && x <= 628-500 && y >= 462 && y <= 467);
assign number_9_bit_0[4] = (x >= 635 -500&& x <= 637-500 && y >= 462 && y <= 467);
assign number_9_bit_0[5] = (x >= 635-500 && x <= 637-500 && y >= 471 && y <= 476);

	
	 

	always @ (posedge clk)
		begin
			case (score_counter)
				10'd0: bit_0 = number_0_bit_0;
				10'd1: bit_0 = number_1_bit_0;
				10'd2: bit_0 = number_2_bit_0;
				10'd3: bit_0 = number_3_bit_0;
				10'd4: bit_0 = number_4_bit_0;
				10'd5: bit_0 = number_5_bit_0;
				10'd6: bit_0 = number_6_bit_0;
				10'd7: bit_0 = number_7_bit_0;
				10'd8: bit_0 = number_8_bit_0;
				10'd9: bit_0 = number_9_bit_0;
				10'd10: bit_0 = number_0_bit_0;
				10'd11: bit_0 = number_1_bit_0;
				10'd12: bit_0 = number_2_bit_0;
				10'd13: bit_0 = number_3_bit_0;
				10'd14: bit_0 = number_4_bit_0;
				10'd15: bit_0 = number_5_bit_0;
				10'd16: bit_0 = number_6_bit_0;
				10'd17: bit_0 = number_7_bit_0;
				10'd18: bit_0 = number_8_bit_0;
				10'd19: bit_0 = number_9_bit_0;
				10'd20: bit_0 = number_0_bit_0;
				10'd21: bit_0 = number_1_bit_0;
				10'd22: bit_0 = number_2_bit_0;
				10'd23: bit_0 = number_3_bit_0;
				10'd24: bit_0 = number_4_bit_0;
				10'd25: bit_0 = number_5_bit_0;
				10'd26: bit_0 = number_6_bit_0;
				10'd27: bit_0 = number_7_bit_0;
				10'd28: bit_0 = number_8_bit_0;
				10'd29: bit_0 = number_9_bit_0;
				10'd30: bit_0 = number_0_bit_0;
				10'd31: bit_0 = number_1_bit_0;
				10'd32: bit_0 = number_2_bit_0;
				10'd33: bit_0 = number_3_bit_0;
				10'd34: bit_0 = number_4_bit_0;
				10'd35: bit_0 = number_5_bit_0;
				10'd36: bit_0 = number_6_bit_0;
				10'd37: bit_0 = number_7_bit_0;
				10'd38: bit_0 = number_8_bit_0;
				10'd39: bit_0 = number_9_bit_0;
				10'd40: bit_0 = number_0_bit_0;
				10'd41: bit_0 = number_1_bit_0;
				10'd42: bit_0 = number_2_bit_0;
				10'd43: bit_0 = number_3_bit_0;
				10'd44: bit_0 = number_4_bit_0;
				10'd45: bit_0 = number_5_bit_0;
				10'd46: bit_0 = number_6_bit_0;
				10'd47: bit_0 = number_7_bit_0;
				10'd48: bit_0 = number_8_bit_0;
				10'd49: bit_0 = number_9_bit_0;
				10'd50: bit_0 = number_0_bit_0;
				10'd51: bit_0 = number_1_bit_0;
				10'd52: bit_0 = number_2_bit_0;
				10'd53: bit_0 = number_3_bit_0;
				10'd54: bit_0 = number_4_bit_0;
				10'd55: bit_0 = number_5_bit_0;
				10'd56: bit_0 = number_6_bit_0;
				10'd57: bit_0 = number_7_bit_0;
				10'd58: bit_0 = number_8_bit_0;
				10'd59: bit_0 = number_9_bit_0;
				10'd60: bit_0 = number_0_bit_0;
				10'd61: bit_0 = number_1_bit_0;
				10'd62: bit_0 = number_2_bit_0;
				10'd63: bit_0 = number_3_bit_0;
				10'd64: bit_0 = number_4_bit_0;
				10'd65: bit_0 = number_5_bit_0;
				10'd66: bit_0 = number_6_bit_0;
				10'd67: bit_0 = number_7_bit_0;
				10'd68: bit_0 = number_8_bit_0;
				10'd69: bit_0 = number_9_bit_0;
				10'd70: bit_0 = number_0_bit_0;
				10'd71: bit_0 = number_1_bit_0;
				10'd72: bit_0 = number_2_bit_0;
				10'd73: bit_0 = number_3_bit_0;
				10'd74: bit_0 = number_4_bit_0;
				10'd75: bit_0 = number_5_bit_0;
				10'd76: bit_0 = number_6_bit_0;
				10'd77: bit_0 = number_7_bit_0;
				10'd78: bit_0 = number_8_bit_0;
				10'd79: bit_0 = number_9_bit_0;
				10'd80: bit_0 = number_0_bit_0;
				10'd81: bit_0 = number_1_bit_0;
				10'd82: bit_0 = number_2_bit_0;
				10'd83: bit_0 = number_3_bit_0;
				10'd84: bit_0 = number_4_bit_0;
				10'd85: bit_0 = number_5_bit_0;
				10'd86: bit_0 = number_6_bit_0;
				10'd87: bit_0 = number_7_bit_0;
				10'd88: bit_0 = number_8_bit_0;
				10'd89: bit_0 = number_9_bit_0;
				10'd90: bit_0 = number_0_bit_0;
				10'd91: bit_0 = number_1_bit_0;
				10'd92: bit_0 = number_2_bit_0;
				10'd93: bit_0 = number_3_bit_0;
				10'd94: bit_0 = number_4_bit_0;
				10'd95: bit_0 = number_5_bit_0;
				10'd96: bit_0 = number_6_bit_0;
				10'd97: bit_0 = number_7_bit_0;
				10'd98: bit_0 = number_8_bit_0;
				10'd99: bit_0 = number_9_bit_0;
				10'd100: bit_0 = number_0_bit_0;
				10'd101: bit_0 = number_1_bit_0;
				10'd102: bit_0 = number_2_bit_0;
				10'd103: bit_0 = number_3_bit_0;
				10'd104: bit_0 = number_4_bit_0;
				10'd105: bit_0 = number_5_bit_0;
				10'd106: bit_0 = number_6_bit_0;
				10'd107: bit_0 = number_7_bit_0;
				10'd108: bit_0 = number_8_bit_0;
				10'd109: bit_0 = number_9_bit_0;
			endcase
		end  // always

// wire number_0_bit_1;
assign number_0_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_0_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_0_bit_1[2] = (x >= 613-500 && x <= 615-500 && y >= 462 && y <= 476);
assign number_0_bit_1[3] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 476);

// wire number_1_bit_1;
assign number_1_bit_1[0] = (x >= 622-500 && x <= 624-500 && y >= 459 && y <= 479);
	
// wire number_2_bit_1;
assign number_2_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_2_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_2_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_2_bit_1[3] = (x >= 613-500 && x <= 615-500 && y >= 471 && y <= 476);
assign number_2_bit_1[4] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 467);

// wire number_3_bit_1;
assign number_3_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_3_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_3_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_3_bit_1[3] = (x >= 622-500 && x <= 624-500 && y >= 471 && y <= 476);
assign number_3_bit_1[4] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 467);

// wire number_4_bit_1;
assign number_4_bit_1[0] = (x >= 613 -500&& x <= 615-500 && y >= 459 && y <= 470);
assign number_4_bit_1[1] = (x >= 622-500 && x <= 624-500 && y >= 459 && y <= 479);
assign number_4_bit_1[2] = (x >= 616-500 && x <= 621-500 && y >= 468 && y <= 470);

// wire number_5_bit_1;
assign number_5_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_5_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_5_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_5_bit_1[3] = (x >= 613-500 && x <= 615-500 && y >= 462 && y <= 467);
assign number_5_bit_1[4] = (x >= 622-500 && x <= 624-500 && y >= 471 && y <= 476);

// wire number_6_bit_1;
assign number_6_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_6_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_6_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_6_bit_1[3] = (x >= 613-500 && x <= 615-500 && y >= 462 && y <= 467);
assign number_6_bit_1[4] = (x >= 613-500 && x <= 615-500 && y >= 471 && y <= 476);
assign number_6_bit_1[5] = (x >= 622-500 && x <= 624-500 && y >= 471 && y <= 476);

// wire number_7_bit_1;
assign number_7_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_7_bit_1[1] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 479);

// wire number_8_bit_1;
assign number_8_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_8_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_8_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_8_bit_1[3] = (x >= 613-500 && x <= 615-500 && y >= 462 && y <= 467);
assign number_8_bit_1[4] = (x >= 613-500 && x <= 615-500 && y >= 471 && y <= 476);
assign number_8_bit_1[5] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 467);
assign number_8_bit_1[6] = (x >= 622-500 && x <= 624-500 && y >= 471 && y <= 476);

// wire number_9_bit_1;
assign number_9_bit_1[0] = (x >= 613-500 && x <= 624-500 && y >= 459 && y <= 461);
assign number_9_bit_1[1] = (x >= 613-500 && x <= 624-500 && y >= 468 && y <= 470);
assign number_9_bit_1[2] = (x >= 613-500 && x <= 624-500 && y >= 477 && y <= 479);
assign number_9_bit_1[3] = (x >= 613-500 && x <= 615-500 && y >= 462 && y <= 467);
assign number_9_bit_1[4] = (x >= 622-500 && x <= 624-500 && y >= 462 && y <= 467);
assign number_9_bit_1[5] = (x >= 622-500 && x <= 624-500 && y >= 471 && y <= 476);

	always @ (posedge clk)
		begin
			case (score_counter)
				10'd0: bit_1 = number_0_bit_1;
				10'd1: bit_1 = number_0_bit_1;
				10'd2: bit_1 = number_0_bit_1;
				10'd3: bit_1 = number_0_bit_1;
				10'd4: bit_1 = number_0_bit_1;
				10'd5: bit_1 = number_0_bit_1;
				10'd6: bit_1 = number_0_bit_1;
				10'd7: bit_1 = number_0_bit_1;
				10'd8: bit_1 = number_0_bit_1;
				10'd9: bit_1 = number_0_bit_1;
				10'd10: bit_1 = number_1_bit_1;
				10'd11: bit_1 = number_1_bit_1;
				10'd12: bit_1 = number_1_bit_1;
				10'd13: bit_1 = number_1_bit_1;
				10'd14: bit_1 = number_1_bit_1;
				10'd15: bit_1 = number_1_bit_1;
				10'd16: bit_1 = number_1_bit_1;
				10'd17: bit_1 = number_1_bit_1;
				10'd18: bit_1 = number_1_bit_1;
				10'd19: bit_1 = number_1_bit_1;
				10'd20: bit_1 = number_2_bit_1;
				10'd21: bit_1 = number_2_bit_1;
				10'd22: bit_1 = number_2_bit_1;
				10'd23: bit_1 = number_2_bit_1;
				10'd24: bit_1 = number_2_bit_1;
				10'd25: bit_1 = number_2_bit_1;
				10'd26: bit_1 = number_2_bit_1;
				10'd27: bit_1 = number_2_bit_1;
				10'd28: bit_1 = number_2_bit_1;
				10'd29: bit_1 = number_2_bit_1;
				10'd30: bit_1 = number_3_bit_1;
				10'd31: bit_1 = number_3_bit_1;
				10'd32: bit_1 = number_3_bit_1;
				10'd33: bit_1 = number_3_bit_1;
				10'd34: bit_1 = number_3_bit_1;
				10'd35: bit_1 = number_3_bit_1;
				10'd36: bit_1 = number_3_bit_1;
				10'd37: bit_1 = number_3_bit_1;
				10'd38: bit_1 = number_3_bit_1;
				10'd39: bit_1 = number_3_bit_1;
				10'd40: bit_1 = number_4_bit_1;
				10'd41: bit_1 = number_4_bit_1;
				10'd42: bit_1 = number_4_bit_1;
				10'd43: bit_1 = number_4_bit_1;
				10'd44: bit_1 = number_4_bit_1;
				10'd45: bit_1 = number_4_bit_1;
				10'd46: bit_1 = number_4_bit_1;
				10'd47: bit_1 = number_4_bit_1;
				10'd48: bit_1 = number_4_bit_1;
				10'd49: bit_1 = number_4_bit_1;
				10'd50: bit_1 = number_5_bit_1;
				10'd51: bit_1 = number_5_bit_1;
				10'd52: bit_1 = number_5_bit_1;
				10'd53: bit_1 = number_5_bit_1;
				10'd54: bit_1 = number_5_bit_1;
				10'd55: bit_1 = number_5_bit_1;
				10'd56: bit_1 = number_5_bit_1;
				10'd57: bit_1 = number_5_bit_1;
				10'd58: bit_1 = number_5_bit_1;
				10'd59: bit_1 = number_5_bit_1;
				10'd60: bit_1 = number_6_bit_1;
				10'd61: bit_1 = number_6_bit_1;
				10'd62: bit_1 = number_6_bit_1;
				10'd63: bit_1 = number_6_bit_1;
				10'd64: bit_1 = number_6_bit_1;
				10'd65: bit_1 = number_6_bit_1;
				10'd66: bit_1 = number_6_bit_1;
				10'd67: bit_1 = number_6_bit_1;
				10'd68: bit_1 = number_6_bit_1;
				10'd69: bit_1 = number_6_bit_1;
				10'd70: bit_1 = number_7_bit_1;
				10'd71: bit_1 = number_7_bit_1;
				10'd72: bit_1 = number_7_bit_1;
				10'd73: bit_1 = number_7_bit_1;
				10'd74: bit_1 = number_7_bit_1;
				10'd75: bit_1 = number_7_bit_1;
				10'd76: bit_1 = number_7_bit_1;
				10'd77: bit_1 = number_7_bit_1;
				10'd78: bit_1 = number_7_bit_1;
				10'd79: bit_1 = number_7_bit_1;
				10'd80: bit_1 = number_8_bit_1;
				10'd81: bit_1 = number_8_bit_1;
				10'd82: bit_1 = number_8_bit_1;
				10'd83: bit_1 = number_8_bit_1;
				10'd84: bit_1 = number_8_bit_1;
				10'd85: bit_1 = number_8_bit_1;
				10'd86: bit_1 = number_8_bit_1;
				10'd87: bit_1 = number_8_bit_1;
				10'd88: bit_1 = number_8_bit_1;
				10'd89: bit_1 = number_8_bit_1;
				10'd90: bit_1 = number_9_bit_1;
				10'd91: bit_1 = number_9_bit_1;
				10'd92: bit_1 = number_9_bit_1;
				10'd93: bit_1 = number_9_bit_1;
				10'd94: bit_1 = number_9_bit_1;
				10'd95: bit_1 = number_9_bit_1;
				10'd96: bit_1 = number_9_bit_1;
				10'd97: bit_1 = number_9_bit_1;
				10'd98: bit_1 = number_9_bit_1;
				10'd99: bit_1 = number_9_bit_1;
				10'd100: bit_1 = number_0_bit_1;
				10'd101: bit_1 = number_0_bit_1;
				10'd102: bit_1 = number_0_bit_1;
				10'd103: bit_1 = number_0_bit_1;
				10'd104: bit_1 = number_0_bit_1;
				10'd105: bit_1 = number_0_bit_1;
				10'd106: bit_1 = number_0_bit_1;
				10'd107: bit_1 = number_0_bit_1;
				10'd108: bit_1 = number_0_bit_1;
				10'd109: bit_1 = number_0_bit_1;
			endcase
		end  // always

// wire number_0_bit_2;
assign number_0_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_0_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_0_bit_2[2] = (x >= 600-500 && x <= 602-500 && y >= 462 && y <= 476);
assign number_0_bit_2[3] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 476);

// wire number_1_bit_2;
assign number_1_bit_2[0] = (x >= 609-500 && x <= 611-500 && y >= 459 && y <= 479);
	
// wire number_2_bit_2;
assign number_2_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_2_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_2_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_2_bit_2[3] = (x >= 600-500 && x <= 602-500 && y >= 471 && y <= 476);
assign number_2_bit_2[4] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 467);

// wire number_3_bit_2;
assign number_3_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_3_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_3_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_3_bit_2[3] = (x >= 609-500 && x <= 611-500 && y >= 471 && y <= 476);
assign number_3_bit_2[4] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 467);

// wire number_4_bit_2;
assign number_4_bit_2[0] = (x >= 600-500 && x <= 602-500 && y >= 459 && y <= 470);
assign number_4_bit_2[1] = (x >= 609-500 && x <= 611-500 && y >= 459 && y <= 479);
assign number_4_bit_2[2] = (x >= 603-500 && x <= 608-500 && y >= 468 && y <= 470);

// wire number_5_bit_1;
assign number_5_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_5_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_5_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_5_bit_2[3] = (x >= 600-500 && x <= 602-500 && y >= 462 && y <= 467);
assign number_5_bit_2[4] = (x >= 609-500 && x <= 611-500 && y >= 471 && y <= 476);

// wire number_6_bit_2;
assign number_6_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_6_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_6_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_6_bit_2[3] = (x >= 600-500 && x <= 602-500 && y >= 462 && y <= 467);
assign number_6_bit_2[4] = (x >= 600-500 && x <= 602-500 && y >= 471 && y <= 476);
assign number_6_bit_2[5] = (x >= 609-500 && x <= 611-500 && y >= 471 && y <= 476);

// wire number_7_bit_2;
assign number_7_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_7_bit_2[1] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 479);

// wire number_8_bit_2;
assign number_8_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_8_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_8_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_8_bit_2[3] = (x >= 600-500 && x <= 602-500 && y >= 462 && y <= 467);
assign number_8_bit_2[4] = (x >= 600-500 && x <= 602-500 && y >= 471 && y <= 476);
assign number_8_bit_2[5] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 467);
assign number_8_bit_2[6] = (x >= 609-500 && x <= 611-500 && y >= 471 && y <= 476);

// wire number_9_bit_2;
assign number_9_bit_2[0] = (x >= 600-500 && x <= 611-500 && y >= 459 && y <= 461);
assign number_9_bit_2[1] = (x >= 600-500 && x <= 611-500 && y >= 468 && y <= 470);
assign number_9_bit_2[2] = (x >= 600-500 && x <= 611-500 && y >= 477 && y <= 479);
assign number_9_bit_2[3] = (x >= 600-500 && x <= 602-500 && y >= 462 && y <= 467);
assign number_9_bit_2[4] = (x >= 609-500 && x <= 611-500 && y >= 462 && y <= 467);
assign number_9_bit_2[5] = (x >= 609-500 && x <= 611-500 && y >= 471 && y <= 476);

	always @ (posedge clk)
		begin
			case (score_counter)
				10'd0: bit_2 = number_0_bit_2;
				10'd1: bit_2 = number_0_bit_2;
				10'd2: bit_2 = number_0_bit_2;
				10'd3: bit_2 = number_0_bit_2;
				10'd4: bit_2 = number_0_bit_2;
				10'd5: bit_2 = number_0_bit_2;
				10'd6: bit_2 = number_0_bit_2;
				10'd7: bit_2 = number_0_bit_2;
				10'd8: bit_2 = number_0_bit_2;
				10'd9: bit_2 = number_0_bit_2;
				10'd10: bit_2 = number_0_bit_2;
				10'd11: bit_2 = number_0_bit_2;
				10'd12: bit_2 = number_0_bit_2;
				10'd13: bit_2 = number_0_bit_2;
				10'd14: bit_2 = number_0_bit_2;
				10'd15: bit_2 = number_0_bit_2;
				10'd16: bit_2 = number_0_bit_2;
				10'd17: bit_2 = number_0_bit_2;
				10'd18: bit_2 = number_0_bit_2;
				10'd19: bit_2 = number_0_bit_2;
				10'd20: bit_2 = number_0_bit_2;
				10'd21: bit_2 = number_0_bit_2;
				10'd22: bit_2 = number_0_bit_2;
				10'd23: bit_2 = number_0_bit_2;
				10'd24: bit_2 = number_0_bit_2;
				10'd25: bit_2 = number_0_bit_2;
				10'd26: bit_2 = number_0_bit_2;
				10'd27: bit_2 = number_0_bit_2;
				10'd28: bit_2 = number_0_bit_2;
				10'd29: bit_2 = number_0_bit_2;
				10'd30: bit_2 = number_0_bit_2;
				10'd31: bit_2 = number_0_bit_2;
				10'd32: bit_2 = number_0_bit_2;
				10'd33: bit_2 = number_0_bit_2;
				10'd34: bit_2 = number_0_bit_2;
				10'd35: bit_2 = number_0_bit_2;
				10'd36: bit_2 = number_0_bit_2;
				10'd37: bit_2 = number_0_bit_2;
				10'd38: bit_2 = number_0_bit_2;
				10'd39: bit_2 = number_0_bit_2;
				10'd40: bit_2 = number_0_bit_2;
				10'd41: bit_2 = number_0_bit_2;
				10'd42: bit_2 = number_0_bit_2;
				10'd43: bit_2 = number_0_bit_2;
				10'd44: bit_2 = number_0_bit_2;
				10'd45: bit_2 = number_0_bit_2;
				10'd46: bit_2 = number_0_bit_2;
				10'd47: bit_2 = number_0_bit_2;
				10'd48: bit_2 = number_0_bit_2;
				10'd49: bit_2 = number_0_bit_2;
				10'd50: bit_2 = number_0_bit_2;
				10'd51: bit_2 = number_0_bit_2;
				10'd52: bit_2 = number_0_bit_2;
				10'd53: bit_2 = number_0_bit_2;
				10'd54: bit_2 = number_0_bit_2;
				10'd55: bit_2 = number_0_bit_2;
				10'd56: bit_2 = number_0_bit_2;
				10'd57: bit_2 = number_0_bit_2;
				10'd58: bit_2 = number_0_bit_2;
				10'd59: bit_2 = number_0_bit_2;
				10'd60: bit_2 = number_0_bit_2;
				10'd61: bit_2 = number_0_bit_2;
				10'd62: bit_2 = number_0_bit_2;
				10'd63: bit_2 = number_0_bit_2;
				10'd64: bit_2 = number_0_bit_2;
				10'd65: bit_2 = number_0_bit_2;
				10'd66: bit_2 = number_0_bit_2;
				10'd67: bit_2 = number_0_bit_2;
				10'd68: bit_2 = number_0_bit_2;
				10'd69: bit_2 = number_0_bit_2;
				10'd70: bit_2 = number_0_bit_2;
				10'd71: bit_2 = number_0_bit_2;
				10'd72: bit_2 = number_0_bit_2;
				10'd73: bit_2 = number_0_bit_2;
				10'd74: bit_2 = number_0_bit_2;
				10'd75: bit_2 = number_0_bit_2;
				10'd76: bit_2 = number_0_bit_2;
				10'd77: bit_2 = number_0_bit_2;
				10'd78: bit_2 = number_0_bit_2;
				10'd79: bit_2 = number_0_bit_2;
				10'd80: bit_2 = number_0_bit_2;
				10'd81: bit_2 = number_0_bit_2;
				10'd82: bit_2 = number_0_bit_2;
				10'd83: bit_2 = number_0_bit_2;
				10'd84: bit_2 = number_0_bit_2;
				10'd85: bit_2 = number_0_bit_2;
				10'd86: bit_2 = number_0_bit_2;
				10'd87: bit_2 = number_0_bit_2;
				10'd88: bit_2 = number_0_bit_2;
				10'd89: bit_2 = number_0_bit_2;
				10'd90: bit_2 = number_0_bit_2;
				10'd91: bit_2 = number_0_bit_2;
				10'd92: bit_2 = number_0_bit_2;
				10'd93: bit_2 = number_0_bit_2;
				10'd94: bit_2 = number_0_bit_2;
				10'd95: bit_2 = number_0_bit_2;
				10'd96: bit_2 = number_0_bit_2;
				10'd97: bit_2 = number_0_bit_2;
				10'd98: bit_2 = number_0_bit_2;
				10'd99: bit_2 = number_0_bit_2;
				10'd100: bit_2 = number_1_bit_2;
				10'd101: bit_2 = number_1_bit_2;
				10'd102: bit_2 = number_1_bit_2;
				10'd103: bit_2 = number_1_bit_2;
				10'd104: bit_2 = number_1_bit_2;
				10'd105: bit_2 = number_1_bit_2;
				10'd106: bit_2 = number_1_bit_2;
				10'd107: bit_2 = number_1_bit_2;
				10'd108: bit_2 = number_1_bit_2;
				10'd109: bit_2 = number_1_bit_2;
			endcase
		end  // always

// wire number_0_bit_3;
assign number_0_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_0_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_0_bit_3[2] = (x >= 587-500 && x <= 589-500 && y >= 462 && y <= 476);
assign number_0_bit_3[3] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 476);

// wire number_1_bit_3;
assign number_1_bit_3[0] = (x >= 596-500 && x <= 598-500 && y >= 459 && y <= 479);
	
// wire number_2_bit_3;
assign number_2_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_2_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 468 && y <= 470);
assign number_2_bit_3[2] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_2_bit_3[3] = (x >= 587-500 && x <= 589-500 && y >= 471 && y <= 476);
assign number_2_bit_3[4] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 467);

// wire number_3_bit_3;
assign number_3_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_3_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 468 && y <= 470);
assign number_3_bit_3[2] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_3_bit_3[3] = (x >= 596-500 && x <= 598-500 && y >= 471 && y <= 476);
assign number_3_bit_3[4] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 467);

// wire number_4_bit_3;
assign number_4_bit_3[0] = (x >= 587-500 && x <= 589-500 && y >= 459 && y <= 470);
assign number_4_bit_3[1] = (x >= 596-500 && x <= 598-500 && y >= 459 && y <= 479);
assign number_4_bit_3[2] = (x >= 590-500 && x <= 595-500 && y >= 468 && y <= 470);

// wire number_5_bit_3;
assign number_5_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_5_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 468 && y <= 470);
assign number_5_bit_3[2] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_5_bit_3[3] = (x >= 587-500 && x <= 589-500 && y >= 462 && y <= 467);
assign number_5_bit_3[4] = (x >= 596-500 && x <= 598-500 && y >= 471 && y <= 476);

// wire number_6_bit_3;
assign number_6_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_6_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 468 && y <= 470);
assign number_6_bit_3[2] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_6_bit_3[3] = (x >= 587-500 && x <= 589-500 && y >= 462 && y <= 467);
assign number_6_bit_3[4] = (x >= 587-500 && x <= 589-500 && y >= 471 && y <= 476);
assign number_6_bit_3[5] = (x >= 596-500 && x <= 598-500 && y >= 471 && y <= 476);

// wire number_7_bit_3;
assign number_7_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_7_bit_3[1] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 479);

// wire number_8_bit_3;
assign number_8_bit_3[0] = (x >= 587 -500&& x <= 598-500 && y >= 459 && y <= 461);
assign number_8_bit_3[1] = (x >= 587 -500&& x <= 598-500 && y >= 468 && y <= 470);
assign number_8_bit_3[2] = (x >= 587 -500&& x <= 598-500 && y >= 477 && y <= 479);
assign number_8_bit_3[3] = (x >= 587-500 && x <= 589-500 && y >= 462 && y <= 467);
assign number_8_bit_3[4] = (x >= 587-500 && x <= 589-500 && y >= 471 && y <= 476);
assign number_8_bit_3[5] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 467);
assign number_8_bit_3[6] = (x >= 596-500 && x <= 598-500 && y >= 471 && y <= 476);

// wire number_9_bit_3;
assign number_9_bit_3[0] = (x >= 587-500 && x <= 598-500 && y >= 459 && y <= 461);
assign number_9_bit_3[1] = (x >= 587-500 && x <= 598-500 && y >= 468 && y <= 470);
assign number_9_bit_3[2] = (x >= 587-500 && x <= 598-500 && y >= 477 && y <= 479);
assign number_9_bit_3[3] = (x >= 587-500 && x <= 589-500 && y >= 462 && y <= 467);
assign number_9_bit_3[4] = (x >= 596-500 && x <= 598-500 && y >= 462 && y <= 467);
assign number_9_bit_3[5] = (x >= 596-500 && x <= 598-500 && y >= 471 && y <= 476);

	always @ (posedge clk)
		begin
			case (score_counter)
				10'd0: bit_3 = number_0_bit_3;
				10'd1: bit_3 = number_0_bit_3;
				10'd2: bit_3 = number_0_bit_3;
				10'd3: bit_3 = number_0_bit_3;
				10'd4: bit_3 = number_0_bit_3;
				10'd5: bit_3 = number_0_bit_3;
				10'd6: bit_3 = number_0_bit_3;
				10'd7: bit_3 = number_0_bit_3;
				10'd8: bit_3 = number_0_bit_3;
				10'd9: bit_3 = number_0_bit_3;
				10'd10: bit_3 = number_0_bit_3;
				10'd11: bit_3 = number_0_bit_3;
				10'd12: bit_3 = number_0_bit_3;
				10'd13: bit_3 = number_0_bit_3;
				10'd14: bit_3 = number_0_bit_3;
				10'd15: bit_3 = number_0_bit_3;
				10'd16: bit_3 = number_0_bit_3;
				10'd17: bit_3 = number_0_bit_3;
				10'd18: bit_3 = number_0_bit_3;
				10'd19: bit_3 = number_0_bit_3;
				10'd20: bit_3 = number_0_bit_3;
				10'd21: bit_3 = number_0_bit_3;
				10'd22: bit_3 = number_0_bit_3;
				10'd23: bit_3 = number_0_bit_3;
				10'd24: bit_3 = number_0_bit_3;
				10'd25: bit_3 = number_0_bit_3;
				10'd26: bit_3 = number_0_bit_3;
				10'd27: bit_3 = number_0_bit_3;
				10'd28: bit_3 = number_0_bit_3;
				10'd29: bit_3 = number_0_bit_3;
				10'd30: bit_3 = number_0_bit_3;
				10'd31: bit_3 = number_0_bit_3;
				10'd32: bit_3 = number_0_bit_3;
				10'd33: bit_3 = number_0_bit_3;
				10'd34: bit_3 = number_0_bit_3;
				10'd35: bit_3 = number_0_bit_3;
				10'd36: bit_3 = number_0_bit_3;
				10'd37: bit_3 = number_0_bit_3;
				10'd38: bit_3 = number_0_bit_3;
				10'd39: bit_3 = number_0_bit_3;
				10'd40: bit_3 = number_0_bit_3;
				10'd41: bit_3 = number_0_bit_3;
				10'd42: bit_3 = number_0_bit_3;
				10'd43: bit_3 = number_0_bit_3;
				10'd44: bit_3 = number_0_bit_3;
				10'd45: bit_3 = number_0_bit_3;
				10'd46: bit_3 = number_0_bit_3;
				10'd47: bit_3 = number_0_bit_3;
				10'd48: bit_3 = number_0_bit_3;
				10'd49: bit_3 = number_0_bit_3;
				10'd50: bit_3 = number_0_bit_3;
				10'd51: bit_3 = number_0_bit_3;
				10'd52: bit_3 = number_0_bit_3;
				10'd53: bit_3 = number_0_bit_3;
				10'd54: bit_3 = number_0_bit_3;
				10'd55: bit_3 = number_0_bit_3;
				10'd56: bit_3 = number_0_bit_3;
				10'd57: bit_3 = number_0_bit_3;
				10'd58: bit_3 = number_0_bit_3;
				10'd59: bit_3 = number_0_bit_3;
				10'd60: bit_3 = number_0_bit_3;
				10'd61: bit_3 = number_0_bit_3;
				10'd62: bit_3 = number_0_bit_3;
				10'd63: bit_3 = number_0_bit_3;
				10'd64: bit_3 = number_0_bit_3;
				10'd65: bit_3 = number_0_bit_3;
				10'd66: bit_3 = number_0_bit_3;
				10'd67: bit_3 = number_0_bit_3;
				10'd68: bit_3 = number_0_bit_3;
				10'd69: bit_3 = number_0_bit_3;
				10'd70: bit_3 = number_0_bit_3;
				10'd71: bit_3 = number_0_bit_3;
				10'd72: bit_3 = number_0_bit_3;
				10'd73: bit_3 = number_0_bit_3;
				10'd74: bit_3 = number_0_bit_3;
				10'd75: bit_3 = number_0_bit_3;
				10'd76: bit_3 = number_0_bit_3;
				10'd77: bit_3 = number_0_bit_3;
				10'd78: bit_3 = number_0_bit_3;
				10'd79: bit_3 = number_0_bit_3;
				10'd80: bit_3 = number_0_bit_3;
				10'd81: bit_3 = number_0_bit_3;
				10'd82: bit_3 = number_0_bit_3;
				10'd83: bit_3 = number_0_bit_3;
				10'd84: bit_3 = number_0_bit_3;
				10'd85: bit_3 = number_0_bit_3;
				10'd86: bit_3 = number_0_bit_3;
				10'd87: bit_3 = number_0_bit_3;
				10'd88: bit_3 = number_0_bit_3;
				10'd89: bit_3 = number_0_bit_3;
				10'd90: bit_3 = number_0_bit_3;
				10'd91: bit_3 = number_0_bit_3;
				10'd92: bit_3 = number_0_bit_3;
				10'd93: bit_3 = number_0_bit_3;
				10'd94: bit_3 = number_0_bit_3;
				10'd95: bit_3 = number_0_bit_3;
				10'd96: bit_3 = number_0_bit_3;
				10'd97: bit_3 = number_0_bit_3;
				10'd98: bit_3 = number_0_bit_3;
				10'd99: bit_3 = number_0_bit_3;
				10'd100: bit_3 = number_0_bit_3;
				10'd101: bit_3 = number_0_bit_3;
				10'd102: bit_3 = number_0_bit_3;
				10'd103: bit_3 = number_0_bit_3;
				10'd104: bit_3 = number_0_bit_3;
				10'd105: bit_3 = number_0_bit_3;
				10'd106: bit_3 = number_0_bit_3;
				10'd107: bit_3 = number_0_bit_3;
				10'd108: bit_3 = number_0_bit_3;
				10'd109: bit_3 = number_0_bit_3;
			endcase
		end  // always

// End number generate
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////// Fixed OVER Generate

////////////////////////////////////////////////////////////////////////////////////// LETTER OO
wire [3:0] Letter_OO;
assign Letter_OO[0] = (x >= 90 && x <= 180 && y >= 190 && y <= 200);
assign Letter_OO[1] = (x >= 90 && x <= 180 && y >= 300 && y <= 310);
assign Letter_OO[2] = (x >= 90 && x <= 100 && y >= 201 && y <= 299);
assign Letter_OO[3] = (x >= 170 && x <= 180 && y >= 201 && y <= 299);
////////////////////////////////////////////////////////////////////////////////////// END LETTER OO

////////////////////////////////////////////////////////////////////////////////////// LETTER VV
wire [1:0] Letter_VV;
assign Letter_VV[0] = (x - 2 * y <= 280 - 2 * 310 + 300 && x - 2 * y >= 280 - 2 * 310  && 2 * x + y >= 2 * 280 + 310 - 13 && 2 * x + y <= 2 * 280 + 310 + 13);
assign Letter_VV[1] = (2 * x - y >= 2 * 280 - 310 - 13 && 2 * x - y <= 2 * 280 - 310 + 13  && x + 2 * y >= 280 + 2 * 310 - 300 && x + 2 * y <= 280 + 2 * 310 );
////////////////////////////////////////////////////////////////////////////////////// END LETTER VV

////////////////////////////////////////////////////////////////////////////////////// LETTER EE
wire [4:0] Letter_EE;
assign Letter_EE[0] = (x >= 380 && x <= 470 && y >= 190 && y <= 200);
assign Letter_EE[1] = (x >= 380 && x <= 470 && y >= 245 && y <= 255);
assign Letter_EE[2] = (x >= 380 && x <= 470 && y >= 300 && y <= 310);
assign Letter_EE[3] = (x >= 380 && x <= 390 && y >= 201 && y <= 244);
assign Letter_EE[4] = (x >= 380 && x <= 390 && y >= 256 && y <= 299);
////////////////////////////////////////////////////////////////////////////////////// END LETTER EE

////////////////////////////////////////////////////////////////////////////////////// LETTER RR
wire [5:0] Letter_RR;
assign Letter_RR[0] = (x >= 500 && x <= 590 && y >= 190 && y <= 200);
assign Letter_RR[1] = (x >= 500 && x <= 590 && y >= 245 && y <= 255);
assign Letter_RR[2] = (x >= 500 && x <= 510 && y >= 201 && y <= 244);
assign Letter_RR[3] = (x >= 500 && x <= 510 && y >= 256 && y <= 310);
assign Letter_RR[4] = (x >= 580 && x <= 590 && y >= 201 && y <= 244);
assign Letter_RR[5] = (x - y <= 511 - 256 + 7 && x - y >= 511 - 256 - 7 && x + y <= 511 + 256 +130 && x + y >= 511 + 256);

////////////////////////////////////////////////////////////////////////////////////// END LETTER RR

reg [3:0] Letter_OO_on;
reg [1:0] Letter_VV_on;
reg [4:0] Letter_EE_on;
reg [5:0] Letter_RR_on;



always @ (posedge clk)
	begin
		if (fail_case)
			begin
				Letter_OO_on <= Letter_OO;
				Letter_VV_on <= Letter_VV;
				Letter_EE_on <= Letter_EE;
				Letter_RR_on <= Letter_RR;
				
				
			end
		
			
	end

////////////////////////////////////////////////////////////////////////////////////// End Fixed OVER Generate

reg [24:0] slowcounter;
reg [9:0] offset;

always @(posedge clk or posedge ciguli) begin
    if (ciguli) begin
        slowcounter <= 0;
        offset <= 0;
    end else begin
        if (slowcounter == 1_000_000) begin // Yaklaşık 0.5 saniyede bir güncelleme (50MHz / 2)
            slowcounter <= 0;
            offset <= offset + 1;
        end else begin
            slowcounter <= slowcounter + 1;
        end
    end
end

    // RGB control
    always @(*) begin
        if(~video_on) begin
            red = 8'h00;          // black (no value) outside display area
            green = 8'h00;
            blue = 8'h00;
			end else if(circle_on && ((x - circle_x_reg) * (x - circle_x_reg) + (y - circle_y_reg) * (y - circle_y_reg)) <= (CIRCLE_RADIUS * CIRCLE_RADIUS)) begin
				red = 8'hFF;     // red circle
				green = 8'h00;
				blue = 8'h00;
			end else if(circle1_on && ((x - circle_x1_reg) * (x - circle_x1_reg) + (y - circle_y1_reg) * (y - circle_y1_reg)) <= (CIRCLE_RADIUS * CIRCLE_RADIUS)) begin
				red = 8'h00;
				green = 8'hFF;   // green circle
				blue = 8'h00;
			end else if(circle2_on && ((y - circle_y2_reg) * (y - circle_y2_reg) + (x - circle_x2_reg) * (x - circle_x2_reg)) <= (CIRCLE_RADIUS * CIRCLE_RADIUS)) begin
				red = 8'h00;
				green = 8'h00;
				blue = 8'hFF;    // blue circle
			end else if(circle3_on && ((y - circle_y3_reg) * (y - circle_y3_reg) + (x - circle_x3_reg) * (x - circle_x3_reg)) <= (CIRCLE_RADIUS * CIRCLE_RADIUS)) begin
				red = 8'hFF;
				green = 8'hFF;
				blue = 8'h00;    // yellow circle
			end else if(plus4_on) begin
				red = 8'h00;
				green = 8'hFF;
				blue = 8'hFF;    // cyan plus sign
			end else if(plus5_on) begin
				red = 8'hFF;
				green = 8'h00;
				blue = 8'hFF;    // magenta plus sign
			end else if(plus6_on) begin
				red = 8'hFF;
				green = 8'h80;
				blue = 8'h00;    // orange plus sign
			end else if(plus7_on) begin
				red = 8'h80;
				green = 8'h00;
				blue = 8'h80;    // purple plus sign
			end else if (((x + offset) % 20 == 0) && (y % 20 == 0)) begin
				red = 8'hFF;          // white dots at every 20 pixels
				green = 8'hFF;
				blue = 8'hFF;				
			end else if (in_rocket_tip && ShootingModeIndicator==0) begin
            red = 8'h00;
            green = 8'hff;
            blue = 8'h00;
			end else if (in_rocket_tip && ShootingModeIndicator==1) begin
            red = 8'hff;
            green = 8'h00;
            blue = 8'h00;
        end else if (rocket_body && ShootingModeIndicator ==0) begin
            red = 8'h00;    // rocket body
            green = 8'hff;
            blue = 8'h00;
			end else if (rocket_body && ShootingModeIndicator ==1) begin
            red = 8'hff;    // rocket body
            green = 8'h00;
            blue = 8'h00;
        end else if (Letter_S) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (Letter_C) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (Letter_O) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (Letter_R) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
        end else if (Letter_E) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (Sign_Equal) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (bit_0) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (bit_1) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (bit_2) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
		  end else if (bit_3) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
        end else if (Letter_OO_on) begin
            red = 8'hFF;
            green = 8'h00;
            blue = 8'h00;
		  end else if (Letter_VV_on) begin
            red = 8'hFF;
            green = 8'h00;
            blue = 8'h00;
		  end else if (Letter_EE_on) begin
            red = 8'hFF;
            green = 8'h00;
            blue = 8'h00;
		  end else if (Letter_RR_on) begin
            red = 8'hFF;
            green = 8'h00;
            blue = 8'h00;
        end else begin
            red = 8'h01;         // dark background
            green =  8'h01;
            blue = 8'h01;
        end
    end
endmodule