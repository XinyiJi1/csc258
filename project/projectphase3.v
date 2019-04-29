// Top module
// Connect top datapath, control and vga
module projectphase3
	 (CLOCK_50,						//	On Board 50 MHz
	 // Your inputs and outputs here
    KEY,
	 SW,
	 PS2_DAT,
	 PS2_CLK,
	 HEX0,
	 HEX1,
	 // The ports below are for the VGA output.  Do not change.
	 VGA_CLK,   						//	VGA Clock
	 VGA_HS,							//	VGA H_SYNC
	 VGA_VS,							//	VGA V_SYNC
	 VGA_BLANK_N,						//	VGA BLANK
	 VGA_SYNC_N,						//	VGA SYNC
	 VGA_R,   						//	VGA Red[9:0]
	 VGA_G,	 						//	VGA Green[9:0]
	 VGA_B   						//	VGA Blue[9:0]
	 );

	 input CLOCK_50;				//	50 MHz
	 input [3:0] KEY;
	 input [9:0] SW;
	 inout PS2_DAT;
	 inout PS2_CLK;

	 // Declare your inputs and outputs here
	 output [6:0] HEX0, HEX1;
	 // Do not change the following outputs
	 output			VGA_CLK;   				//	VGA Clock
	 output			VGA_HS;					//	VGA H_SYNC
	 output			VGA_VS;					//	VGA V_SYNC
	 output			VGA_BLANK_N;				//	VGA BLANK
	 output			VGA_SYNC_N;				//	VGA SYNC
	 output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	 output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	 output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	 
	
	 wire resetn;
	 assign resetn = KEY[0];
	
	 // Create the colour, x, y and writeEn wires that are inputs to the controller.
	 wire [2:0] colour;
	 wire [8:0] x;
	 wire [6:0] y;
	 wire birdEn, treeEn, foodEn, eraseEn, overEn;
	 wire hit, shift, finish_erase, reset_data;
	 wire [7:0] count_food, useless;
	 wire restart, up;

	 // Create an Instance of a VGA controller - there can be only one!
	 // Define the number of colours as well as the initial background
	 // image file (.MIF) for the controller.
	 vga_adapter VGA(
		  .resetn(resetn),
	     .clock(CLOCK_50),
		  .colour(colour),
		  .x(x),
		  .y(y),
		  .plot(1'b1),
		  /* Signals for the DAC to drive the monitor. */
		  .VGA_R(VGA_R),
		  .VGA_G(VGA_G),
		  .VGA_B(VGA_B),
		  .VGA_HS(VGA_HS),
		  .VGA_VS(VGA_VS),
		  .VGA_BLANK(VGA_BLANK_N),
		  .VGA_SYNC(VGA_SYNC_N),
		  .VGA_CLK(VGA_CLK));
	 defparam VGA.RESOLUTION = "160x120";
	 defparam VGA.MONOCHROME = "FALSE";
	 defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	 defparam VGA.BACKGROUND_IMAGE = "black.mif";
	 
	 // Instance keyboard controller
	  keyboard_tracker #(.PULSE_OR_HOLD(0)) k0(
    .clock(CLOCK_50),
	 .reset(resetn),
	 .PS2_CLK(PS2_CLK),
	 .PS2_DAT(PS2_DAT),
	 
	 .w(up), 
	 .s(useless[0]), 
	 .a(useless[1]), 
	 .d(useless[2]),
	 
	 .up(useless[3]), 
	 .down(useless[4]),
	 .left(useless[5]), 
	 .right(useless[6]), 
	 .space(restart), 
	 .enter(useless[7])
	 );
    
    // Instansiate datapath
	 datapath d0(
	     .clock(CLOCK_50),
		  .resetn(resetn),
		  .reset_data(reset_data),
		  .shift(shift),
		  .fly(up),
		  .birdEn(birdEn),
		  .treeEn(treeEn),
		  .foodEn(foodEn),
		  .eraseEn(eraseEn),
		  .overEn(overEn),
		  .finish_erase(finish_erase),
		  .hit(hit),
		  .x_vga(x),
		  .y_vga(y),
		  .colour_vga(colour),
		  .count_food(count_food)
	     );

    // Instansiate FSM control
	 control c0(
	     .clock(CLOCK_50),
        .resetn(resetn),
		  .hit(hit),
		  .go(~restart),
		  .finish_erase(finish_erase),
		  .birdEn(birdEn),
		  .treeEn(treeEn),
		  .foodEn(foodEn),
		  .eraseEn(eraseEn),
		  .overEn(overEn),
		  .shift(shift),
		  .reset_data(reset_data)
        );
		  
	 // Instansiate HEX decoder to record the score in lower 4 bits
	 hex H0( 
          .hex_digit(count_food[3:0]),  
          .segments(HEX0) 
          ); 
           
	 // Instansiate HEX decoder to record the score in higher 4 bits
    hex    H1( 
          .hex_digit(count_food[7:4]),  
          .segments(HEX1) 
          ); 

endmodule


// Module to draw bird
// Connect to major datapath
module draw_bird(
    input clock, resetn, birdEn,
    input [8:0] loc_xb,
	 input [6:0] loc_yb,
	 
    output [8:0] x_out,
    output [6:0] y_out,
    output [2:0] colour_out
	 );
	
    reg [8:0] x;
    reg [6:0] y;
    reg [1:0] count_x;
    reg [1:0] count_y;
	
    wire j, birdEny;

	 // Registers x, y with respective to input logic
    always @(posedge clock) 
	     begin
            if(resetn == 1'b0)
                begin
                    x <= 9'd20;
                    y <= 7'd40;
                end
            else 
                begin
                    x <= loc_xb;
                    y <= loc_yb;
                end
        end

	 // Counter to draw bird's x
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | birdEn == 1'b0)
                count_x <= 2'b00;
            else if (birdEn == 1'b1) begin
               if (count_x == 2'b11)
                   count_x <= 2'b00;
               else
                   count_x <= count_x + 1;
            end
        end

    assign j = (count_x == 2'b11) ? 1 : 0;
    assign birdEny = birdEn & j;

	 // Counter to draw bird's y
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | birdEn == 1'b0)
                count_y <= 2'b00;
            else if (birdEny == 1'b1) begin
                if (count_y == 2'b11)
                    count_y <= 2'b00;
                else
                    count_y <= count_y + 1;
            end
        end

	 // Assign a direct value to colour_here because bird won't change its colour
    assign colour_out = 3'b100;
    assign x_out = x - count_x;
    assign y_out = y + count_y;
endmodule


// Module to draw food
// Connect to major datapath
module draw_food(
    input clock, resetn, foodEn,
    input [8:0] loc_xf1, loc_xf2, loc_xf3,
	 input [6:0] loc_yf1, loc_yf2, loc_yf3,
	 input f1, f2, f3,
	
    output [8:0] x_out,
	 output [6:0] y_out,
    output [2:0] colour_out
	 );
  
    reg [8:0] x;
    reg [6:0] y;
	 reg [1:0] round;
    reg [2:0] colour;
    reg [1:0] count_x;
	 reg [1:0] count_y;
	 wire j, writeEny;

	 // Registers x, y with respective to input logic and round
    always @(posedge clock)
        begin
            if (resetn == 1'b0)
                begin
                    x <= 9'b000000000;
				        y <= 7'b0000000;
				        colour <= 3'b110;
		          end
            else begin
			       if (round == 2'b00) begin
						  if (f1 == 1'b0)
						      colour <= 3'b110;
					     else
						      colour <= 3'b011;
				        x <= loc_xf1;
				        y <= loc_yf1;
			       end
			       else if (round == 2'b01) begin
					     if (f2 == 1'b0)
						      colour <= 3'b110;
					     else
						    colour <= 3'b011;
				        x <= loc_xf2;
				        y <= loc_yf2;
			       end
			       else if (round == 2'b10) begin
					     if (f3 == 1'b0)
						      colour <= 3'b110;
					     else
						      colour <= 3'b011;
				        x <= loc_xf3;
				        y <= loc_yf3;
			       end
            end    
        end

	 // Counter to draw foods' x
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | foodEn == 1'b0)
                count_x <= 2'b00;
            else if (foodEn == 1'b1)
                begin
                    if (count_x == 2'b11)
			               count_x <= 2'b00;
			           else
                        count_x <= count_x + 1;
                end
        end

    assign j = (count_x == 2'b11) ? 1 : 0;
    assign writeEny = foodEn & j;

	 // Counter to draw foods' y
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | foodEn == 1'b0) begin
                count_y <= 2'b00;
					 round <= 2'b00;
				end
            else if (writeEny == 1'b1) begin
                if (count_y == 2'b11 & !(round == 2'b10)) 
					     begin
				            round <= round + 1'b1;
								count_y <= 2'b00;
						  end
					 else if (count_y == 2'b11 & round == 2'b10)
					     begin
						      round <= 2'b00;
                        count_y <= 2'b00;
			           end
                else
                    count_y <= count_y + 1;
        end
    end

    assign colour_out = colour;
    assign x_out = x - count_x;
    assign y_out = y + count_y;

endmodule


// Module to draw tree
// Connect to major datapath
module draw_tree(
    input clock, resetn, treeEn,
    input [8:0] loc_xt1, loc_xt2, loc_xt3,
	 input [6:0] loc_yt1, loc_yt2, loc_yt3,
    
	 output [8:0] x_out,
	 output [6:0] y_out,
    output [2:0] colour_out
	 );
  
    reg [8:0] x;
    reg [6:0] y;
	 reg [1:0] round;
    reg [2:0] colour;
    reg [2:0] count_x;
	 reg [6:0] count_y;
	 wire j, writeEny;

	 // Registers x, y with respective to input logic and round
    always @(posedge clock)
        begin
            if (resetn == 1'b0)
                begin
                    x <= 9'b000000000;
				        y <= 7'b0000000;
				        colour <= 3'b010;
		          end
            else begin
		          colour <= 3'b010;
			       if (round == 2'b00)
			           begin
				            x <= loc_xt1;
				            y <= loc_yt1;
			           end
			       else if (round == 2'b01)
			           begin
				            x <= loc_xt2;
				            y <= loc_yt2;
			           end
			       else if (round == 2'b10)
			           begin
				            x <= loc_xt3;
				            y <= loc_yt3;
			           end
             end    
        end
	 
    // Counter to draw trees' x
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | treeEn == 1'b0)
                count_x <= 3'b000;
            else if (treeEn == 1'b1)
                begin
                    if (count_x == 3'b111)
			               count_x <= 3'b000;
			           else
                        count_x <= count_x + 1;
                end
        end

    assign j = (count_x == 3'b111) ? 1 : 0;
    assign writeEny = treeEn & j;

	 // Counter to draw trees' y
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | treeEn == 0) begin
                count_y <= 7'b0000000;
			   	 round <= 2'b00;
				end
            else if (writeEny == 1'b1) begin
                if ((count_y == (7'b1110111 - y)) & !(round == 2'b10))
			           begin
                        count_y <= 7'b0000000;
				            round <= round + 1;
				 	     end
				    else if ((count_y == (7'b1110111 - y)) & round == 2'b10)
				        begin
                        count_y <= 7'b0000000;					      
					         round <= 2'b00;
				        end
                else
                    count_y <= count_y + 1;
            end
        end

    assign colour_out = colour;
    assign x_out = x - count_x;
    assign y_out = y + count_y;
	
endmodule


// Module to erase
// Connect to major datapath
module erase(clock, resetn, eraseEn, x_out, y_out, colour_out, finish_erase);
    input clock, resetn, eraseEn;
	 output finish_erase;
    output [8:0] x_out;
    output [6:0] y_out;
    output [2:0] colour_out;
   
    reg [8:0] count_x;
	 reg [6:0] count_y;
	
    wire j, writeEny;

	 // Counter to erase x (count up)
    always @(posedge clock)
        begin
            if (resetn == 1'b0)
                count_x <= 9'b000000000;
            else if (eraseEn == 1'b1) begin
                if (count_x == 9'b010011111)
		 	           count_x <= 9'b000000000;
		 	       else
                    count_x <= count_x + 1;
            end
        end

    assign j = (count_x == 9'b010011111) ? 1 : 0;
    assign writeEny = eraseEn & j;

	 // Counter to erase y (count up)
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | eraseEn == 1'b0)
                count_y <= 7'b0000000;
            else if (writeEny == 1'b1)
                begin
                    if (count_y == 7'b1110111)
                        count_y <= 7'b0000000;
                    else
                        count_y <= count_y + 1;
                end
        end

    assign colour_out = 3'b011;
    assign x_out = count_x;
    assign y_out = count_y;
	 assign finish_erase = ((count_x == 9'b010011111) & (count_y == 7'b1110111)) ? 1 : 0;
	
endmodule


// Module to draw game over screen
// Connect to major datapath
module draw_over(
    input clock, resetn, overEn,
    
    
	 output [8:0] x_out,
	 output [6:0] y_out,
    output [2:0] colour_out
	 );
  
    reg [8:0] x;
	 reg [8:0] x_wide;
    reg [6:0] y;
	 reg [6:0] y_wide;
	 reg [1:0] round;
    reg [2:0] colour;
    reg [8:0] count_x;
	 reg [6:0] count_y;
	 wire j, writeEny;

	 // Registers x, y with respective to input logic and round
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | overEn == 1'b0)
                begin
                    x <= 0;
				        y <= 0;
						  x_wide <= 0;
				        y_wide <= 0;
				        colour <= 3'b000;
		          end
            else begin
		          if (round == 2'b00)
			           begin
								colour <= 3'b000;
				            x <= 0;
				            y <= 0;
								x_wide <= 160;
								y_wide <=120;
			           end
					 else if (round == 2'b01)
			           begin
								colour <= 3'b000;
				            x <= 0;
				            y <= 0;
								x_wide <= 160;
								y_wide <=120;
			           end
			       else if (round == 2'b10)
			           begin
							colour <= 3'b111;
				            x <= 20;
				            y <= 40;
								x_wide <= 120;
								y_wide <= 40;
			           end
					 else if (round == 2'b11)
			           begin
								colour <= 3'b111;		
				            x <= 60;
				            y <= 10;
								x_wide <= 40;
								y_wide <= 100;
			           end
			      
             end    
        end
	 
    // Counter to draw trees' x
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | overEn == 1'b0)
                count_x <= 0;
            else if (overEn == 1'b1)
                begin
                    if (count_x == x_wide)
			               count_x <= 0;
			           else
                        count_x <= count_x + 1;
                end
        end

    assign j = (count_x == x_wide) ? 1 : 0;
    assign writeEny = overEn & j;

	 // Counter to draw trees' y
    always @(posedge clock)
        begin
            if (resetn == 1'b0 | overEn == 1'b0) begin
                count_y <= 7'b0000000;
			   	 round <= 2'b00;
				end
            else if (writeEny == 1'b1) begin
                if ((count_y == y_wide) & !(round == 2'b11))
			           begin
                        count_y <= 7'b0000000;
				            round <= round + 1;
				 	     end
				    else if ((count_y == y_wide) & round == 2'b11)
				        begin
                        count_y <= 7'b0000000;					      
					         round <= 2'b10;
				        end
                else
                    count_y <= count_y + 1;
            end
        end

    assign colour_out = colour;
    assign x_out = x + count_x;
    assign y_out = y + count_y;
	
endmodule


// Major datapath
// Save and update(shift) locations of all objects on screen
// Draw, erase and shift objects on screen
// Receive signals from control module
// Provide x, y and colour information to vga adaptor
module datapath(
    input clock, resetn, shift, fly, reset_data,
	 input birdEn, treeEn, foodEn, eraseEn, overEn,
	
	 output finish_erase,
	 output reg hit,
    output reg [2:0] colour_vga,
    output reg [8:0] x_vga,
	 output reg [6:0] y_vga,
	 output [7:0] count_food
	 );
	
	 // wires
	 wire [8:0] bird_x, tree_x, food_x, erase_x, over_x;
	 wire [6:0] bird_y, tree_y, food_y, erase_y, over_y;
	 wire [2:0] bird_colour, tree_colour, food_colour, erase_colour, over_colour;
	 wire [8:0] xb, xt1, xt2, xt3, xf1, xf2, xf3;
	 wire [6:0] yb, yt1, yt2, yt3, yf1, yf2, yf3, random_out;
	 wire reset, f1, f2, f3;
	
	 // registers to trace locations of all onjects on scree
	 // we don't have to trace locations of trees because they can be calculated according to locations of foods
	 reg [8:0] loc_xb, loc_xf1, loc_xf2, loc_xf3;
	 reg [6:0] loc_yb, loc_yf1, loc_yf2, loc_yf3;
	 reg [6:0] count_food1, count_food2, count_food3;
	 reg food1, food2, food3;  
	 
	 assign reset = (reset_data  == 1'b1) ? 0 : resetn;
	
	 // Register for location of bird
	 always @(posedge shift, negedge reset) 
	     begin
		      if (!reset) begin
			       loc_xb <= 9'd20;
					 loc_yb <= 7'd40;
	         end
				else if (fly)
					 loc_yb <= loc_yb - 3'd4;
				else
			       loc_yb <= loc_yb + 3'd2;
		  end
		  
	 // Register for location of 3 foods
	 always @(posedge shift, negedge reset) 
	     begin
		      if (!reset) begin
			       loc_xf1 <= 9'd112;
			       loc_xf2 <= 9'd165;
			       loc_xf3 <= 9'd218;
					 loc_yf1 <= 7'd105;
					 loc_yf2 <= 7'd65;
					 loc_yf3 <= 7'd90;
				end
	         else begin
					 if (loc_xf1 == 9'd0) begin
					     loc_xf1 <= loc_xf3 + 9'd53;
						  loc_yf1 <= 4'd10 + random_out;
					 end
					 else if (loc_xf2 == 9'd0) begin
					     loc_xf2 <= loc_xf1 + 9'd53;
						  loc_yf2 <= 4'd10 + random_out;
						  
					 end
					 else if (loc_xf3 == 9'd0) begin
					     loc_xf3 <= loc_xf2 + 9'd53;
						  loc_yf3 <= 4'd10 + random_out;
						  
					 end
					 else begin
			           loc_xf1 <= loc_xf1 - 1'b1;
			           loc_xf2 <= loc_xf2 - 1'b1;
			           loc_xf3 <= loc_xf3 - 1'b1;
                end
				end
		  end

	 // genarate random number for height of food
	 random r1(reset, clock, random_out);
		  
    // assign registers' value to wires
	 assign xb = loc_xb;
	 assign yb = loc_yb;
	 assign xf1 = loc_xf1;
	 assign xf2 = loc_xf2;
	 assign xf3 = loc_xf3;
	 assign yf1 = loc_yf1;
	 assign yf2 = loc_yf2;
	 assign yf3 = loc_yf3;
	 assign xt1 = loc_xf1 + 2'b10;
	 assign xt2 = loc_xf2 + 2'b10;
	 assign xt3 = loc_xf3 + 2'b10;
	 assign yt1 = loc_yf1 + 3'b110;
	 assign yt2 = loc_yf2 + 3'b110;
	 assign yt3 = loc_yf3 + 3'b110;
	 assign f1 = food1;
	 assign f2 = food2;
	 assign f3 = food3;

    // Draw one bird when treeEn is high
    draw_bird db(
        .clock(clock),
        .resetn(reset),
        .birdEn(birdEn),
		  .loc_xb(xb),
		  .loc_yb(yb),
		  .x_out(bird_x),
		  .y_out(bird_y),
		  .colour_out(bird_colour)
        );
	
	 //Draw 3 trees when treeEn is high
    draw_tree dt(
        .clock(clock),
        .resetn(reset),
        .treeEn(treeEn),
		  .loc_xt1(xt1),
		  .loc_xt2(xt2),
		  .loc_xt3(xt3),
		  .loc_yt1(yt1),
		  .loc_yt2(yt2),
		  .loc_yt3(yt3),
		  .x_out(tree_x),
		  .y_out(tree_y),
		  .colour_out(tree_colour)
        );
	
	 //Draw 3 foods when foodEn is high
    draw_food df(
        .clock(clock),
        .resetn(reset),
        .foodEn(foodEn),
		  .loc_xf1(xf1),
		  .loc_xf2(xf2),
		  .loc_xf3(xf3),
		  .loc_yf1(yf1),
		  .loc_yf2(yf2),
		  .loc_yf3(yf3),
		  .f1(f1),
		  .f2(f2),
		  .f3(f3),
		  .x_out(food_x),
		  .y_out(food_y),
		  .colour_out(food_colour)
        );
	  
	 // Erase the whole screen when eraseEn is high
	 erase e0(
	     .clock(clock),
        .resetn(reset),
        .eraseEn(eraseEn),
		  .x_out(erase_x),
		  .y_out(erase_y),
		  .colour_out(erase_colour),
		  .finish_erase(finish_erase)
	     );
	 
    // Draw game over screen if bird hits something	 
	 draw_over o0(
        .clock(clock), 
	     .resetn(reset),
	     .overEn(overEn),
	     .x_out(over_x),
	     .y_out(over_y),
        .colour_out(over_colour)
	 );
		  
	 // Assign outputs of datapath
	 always @(posedge clock)
	 begin
		  if (reset == 0) begin
		      x_vga <= 9'd0;
				y_vga <= 7'd0;
				colour_vga <= 3'd0;
		  end
		  else begin
		      if (birdEn == 1'b1) begin
				    x_vga <= bird_x;
					 y_vga <= bird_y;
					 colour_vga <= bird_colour;
				end
		      else if (treeEn == 1'b1) begin
				    x_vga <= tree_x;
					 y_vga <= tree_y;
					 colour_vga <= tree_colour;
				end
		      else if (foodEn == 1'b1) begin
				    x_vga <= food_x;
					 y_vga <= food_y;
					 colour_vga <= food_colour;
				end
		      else if (eraseEn == 1'b1) begin
				    x_vga <= erase_x;
					 y_vga <= erase_y;
					 colour_vga <= erase_colour;
				end
				else if (overEn == 1'b1) begin
				    x_vga <= over_x;
					 y_vga <= over_y;
					 colour_vga <= over_colour;
			   end
		  end
	 end

    // judge whether the bird hits something
	 always @(*) begin
	    if (reset == 1'b0) begin
		     hit = 1'b0;
		 end
		 else if (yb <= 7'b0000000) begin
		     hit = 1'b1;
		 end
	    else if (yb == 7'b1110100) begin
		     hit = 1'b1;
		 end
		 else if ((xb > (xt1 - 4'd9)) & (xb < (xt1 + 4'd5)) & (yb > (yt1 - 4'd4))) begin
		     hit = 1'b1;
		 end
		 else if ((xb > (xt2 - 4'd9)) & (xb < (xt2 + 4'd5)) & (yb > (yt2 - 4'd4))) begin
		     hit = 1'b1;
		 end
		 else if ((xb > (xt3 - 4'd9)) & (xb < (xt3 + 4'd5)) & (yb > (yt3 - 4'd4))) begin
		     hit = 1'b1;
		 end
		 else if ((xb == (xt1 - 4'd7)) & (yb > (yt1 - 4'd5))) begin
		     hit = 1'b1;
		 end
		 else if ((xb == (xt2 - 4'd7)) & (yb > (yt2 - 4'd5))) begin
		     hit = 1'b1;
		 end
	    else if ((xb == (xt3 - 4'd7)) & (yb > (yt3 - 4'd5))) begin
		     hit = 1'b1;
		 end
		 else begin
		     hit = 1'b0;
		 end
    end
	
    // judge whether the bird eats the food
	 always @(posedge clock) begin
	    if ((reset == 1'b0) | (loc_xf1 == 9'd158) | (loc_xf2 == 9'd158) | (loc_xf3 == 9'd158)) begin
		     food1 <= 1'b0;
			  food2 <= 1'b0;
			  food3 <= 1'b0;
		 end
		 else if ((loc_yb > (loc_yf1 - 4'd4)) & (loc_yb < (loc_yf1 + 4'd4)) & (loc_xb > (loc_xf1 - 4'd4)) & (loc_xb < (loc_xf1 + 4'd4))) begin
		     food1 <= 1'b1;
		 end
		 else if ((loc_yb > (loc_yf2 - 4'd4)) & (loc_yb < (loc_yf2 + 4'd4)) & (loc_xb > (loc_xf2 - 4'd4)) & (loc_xb < (loc_xf2 + 4'd4))) begin
		     food2 <= 1'b1;
		 end
		 else if ((loc_yb > (loc_yf3 - 4'd4)) & (loc_yb < (loc_yf3 + 4'd4)) & (loc_xb > (loc_xf3 - 4'd4)) & (loc_xb < (loc_xf3 + 4'd4))) begin
		     food3 <= 1'b1;
		 end
	 end
	
	always @(posedge f1, negedge reset)
	begin
	    if (reset == 1'b0)
		     count_food1 <= 0;
	    else 
		     count_food1 <= count_food1 + 1;
	end
	
	always @(posedge f2, negedge reset)
	begin
	    if (reset == 1'b0)
			  count_food2 <= 0;
		 else 
			  count_food2 <= count_food2 + 1;
	end
	
	always @(posedge f3, negedge reset)
	begin
	    if (reset == 1'b0)
			  count_food3 <= 0;
		 else 
			  count_food3 <= count_food3 + 1;
	end
	
	assign count_food = count_food1 + count_food2 + count_food3;
	 
endmodule


// Control module
module control(
    input clock, resetn, hit, go, finish_erase,
    output reg birdEn, treeEn, foodEn, eraseEn, overEn, shift, reset_data
    );

    reg [2:0] current_state, next_state;
	 
	 // wires to connect rate driver and frame counter
	 wire [15:0] c0;
	 wire [6:0] c1;
	 wire update1, update2;
    
    localparam  S_WAIT        = 4'd0,
					 S_RESET       = 4'd1,
					 S_ERASE       = 4'd2,
					 S_DRAW_BIRD   = 4'd3,
					 S_DRAW_FOOD   = 4'd4,
					 S_DRAW_TREE   = 4'd5;
                
    // Next state logic aka our state table
    always @(*)
    begin: state_table 
            case (current_state)
                S_WAIT: next_state = (go == 1'b1) ? S_WAIT : S_RESET; // game over page, hold until go signal high
                S_RESET: next_state = (go == 1'b0) ? S_RESET : S_ERASE;
					 S_ERASE: next_state = (finish_erase == 1'b1) ? S_DRAW_FOOD : S_ERASE; // (shift) draw bird after erase finished
                S_DRAW_FOOD: next_state = (update1 == 1'b1) ? S_DRAW_BIRD : S_DRAW_FOOD; // draw food after 1/60s
					 S_DRAW_BIRD: next_state = (update1 == 1'b1) ? S_DRAW_TREE : S_DRAW_BIRD; // draw tree after 1/60s
					 S_DRAW_TREE: begin
					     if (hit == 1'b1)
						      next_state = S_WAIT; // go to the game over page if bird hits something
						  else
						      next_state = (update2 == 1'b1) ? S_ERASE : S_DRAW_TREE; // erase the whole screen roughly every 15 frames
					 end
					 default: next_state = S_ERASE;
        endcase
    end // state_table
   

    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
		  birdEn = 1'b0;
		  treeEn = 1'b0;
		  foodEn = 1'b0;
        eraseEn = 1'b0;
		  overEn = 1'b0;
		  shift = 1'b0;
		  reset_data = 1'b0;

        case (current_state)
            S_WAIT: begin
                overEn = 1'b1;
				end
				S_RESET: begin
				    reset_data = 1'b1;
				end
				S_ERASE: begin
                eraseEn = 1'b1;
					 shift = 1'b1;
            end
            S_DRAW_BIRD: begin
                birdEn = 1'b1;
            end
				S_DRAW_TREE: begin
                treeEn = 1'b1;
            end
				S_DRAW_FOOD: begin
                foodEn = 1'b1;
            end
				// default: don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals
   
    // current_state registers
    always @(posedge clock)
    begin: state_FFs
        if(!resetn)
            current_state <= S_ERASE;
        else
            current_state <= next_state;
    end // state_FFS
	 
	 // count down to get around 60HZ
	 rate_divider r1(
	     .clock(clock),
		  .resetn(resetn),
		  .writeEn(1'b1),
		  .out(c0)
		  );
		 
	 assign update1 = (c0 ==  16'd0) ? 1 : 0;
	
	 // count to move at four pixels per second
	 frame_counter f1(
	     .clock(clock),
	 	  .resetn(resetn),
	 	  .writeEn(update1),
		  .out(c1)
		  );
		  
	 assign update2 = (c1 == 7'd0) ? 1 : 0;
	 
endmodule


// Combine datapath control
// Only for test
module combine(
    input clock,
    input resetn,
	 input go,
	 input fly,
	
    output [8:0] x_vga,
    output [6:0] y_vga,
    output [2:0] colour_vga,
	 output [8:0] count_food
	 );
	 
	 wire birdEn, treeEn, foodEn, eraseEn, overEn;
	 wire hit, shift, finish_erase, reset_data;
	 
	 
	 // Instansiate datapath
	 datapath d0(
	     .clock(clock),
		  .resetn(resetn),
		  .reset_data(reset_data),
		  .shift(shift),
		  .fly(fly),
		  .birdEn(birdEn),
		  .treeEn(treeEn),
		  .foodEn(foodEn),
		  .eraseEn(eraseEn),
		  .overEn(overEn),
		  .finish_erase(finish_erase),
		  .hit(hit),
		  .x_vga(x_vga),
		  .y_vga(y_vga),
		  .colour_vga(colour_vga),
		  .count_food(count_food)
	     );

    // Instansiate FSM control
	 control c0(
	     .clock(clock),
        .resetn(resetn),
		  .hit(hit),
		  .go(go),
		  .finish_erase(finish_erase),
		  .birdEn(birdEn),
		  .treeEn(treeEn),
		  .foodEn(foodEn),
		  .eraseEn(eraseEn),
		  .overEn(overEn),
		  .shift(shift),
		  .reset_data(reset_data)
        );
		  
endmodule


// useful helper modules below
module rate_divider(
	input clock, resetn, writeEn,
	output reg [15:0] out
	);
	
	always @(posedge clock)
	begin
		if (resetn == 1'b0)
			out <= 16'd42000;
		else if (writeEn == 1'b1)
		begin
			if (out == 16'd0)
				out <= 16'd42000;
			else
				out <= out - 1;
		end
	end
	
endmodule


module frame_counter(
	 input clock, resetn, writeEn,
	 output reg [6:0] out
	 );
	 
	 always @(posedge clock)
	 begin
		  if (resetn == 1'b0)
			   out <= 7'd100;
		  else if (writeEn == 1'b1) begin
			   if (out == 7'd0)
				    out <= 7'd100;
			   else
				    out <= out - 1;
		  end
	 end
	 
endmodule


module hex(hex_digit, segments); 
    input [3:0] hex_digit; 
    output reg [6:0] segments; 
      
    always @(*) 
        case (hex_digit) 
            4'h0: segments = 7'b1000000; 
            4'h1: segments = 7'b1111001; 
            4'h2: segments = 7'b0100100; 
            4'h3: segments = 7'b0110000; 
            4'h4: segments = 7'b0011001; 
            4'h5: segments = 7'b0010010; 
            4'h6: segments = 7'b0000010; 
            4'h7: segments = 7'b1111000; 
            4'h8: segments = 7'b0000000; 
            4'h9: segments = 7'b0011000; 
            4'hA: segments = 7'b0001000; 
            4'hB: segments = 7'b0000011; 
            4'hC: segments = 7'b1000110; 
            4'hD: segments = 7'b0100001; 
            4'hE: segments = 7'b0000110; 
            4'hF: segments = 7'b0001110;    
            default: segments = 7'h7f; 
        endcase 
endmodule 


module random(resetn, enable, q);
	input resetn, enable;
	output [6:0] q;
	wire [3:0] ran4;
	wire [5:0] ran6;
	assign q = ran4 + ran6 + 5'd20;
	
	random4 r4(enable, resetn, ran4);
	random6 r6(enable, resetn, ran6);
	
endmodule


module random4(clk, reset_n, q);
	input clk, reset_n;
	output [3:0] q;
	
	dff_1 r1(clk, reset_n, q[2] ^ q[3], q[0]);
	dff_2 r2(clk, reset_n, q[0], q[1]);
	dff_2 r3(clk, reset_n, q[1], q[2]);
	dff_2 r4(clk, reset_n, q[2], q[3]);
	
endmodule


module random6(clk, reset_n, q);
	input clk, reset_n;
	output [5:0] q;
	wire qq1;
	assign qq1 = q[5] ^ q[3];
	
	dff_1 r5(clk, reset_n, qq1 ^ q[2], q[0]);
	dff_2 r6(clk, reset_n, q[0], q[1]);
	dff_2 r7(clk, reset_n, q[1], q[2]);
	dff_2 r8(clk, reset_n, q[2], q[3]);
	dff_2 r9(clk, reset_n, q[3], q[4]);
	dff_2 r10(clk, reset_n, q[4], q[5]);
	
endmodule


module dff_1(clk, reset_n, data_in, q);
	input clk, reset_n, data_in;
	output reg q;
	always @(posedge clk, negedge reset_n)
		begin
			if (reset_n == 0)
				q <= 1'b0;
			else
				q <= data_in;
			end
			
endmodule


module dff_2(clk, reset_n, data_in, q);
	input clk, reset_n, data_in;
	output reg q;
	always @(posedge clk, negedge reset_n)
		begin
			if (reset_n == 0)
				q <= 1'b1;
			else
				q <=data_in;
			end
			
endmodule
