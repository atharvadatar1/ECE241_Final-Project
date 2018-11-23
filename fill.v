// Part 2 skeleton

module fill
	(
		CLOCK_50,						//	On Board 50 MHz
		SW,
		KEY,							// On Board Keys
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

	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;					
	input [9:0] SW;
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire [7:0] marioX, barrelX;
	wire [6:0] marioY, barrelY;
	reg userIn;
	wire [7:0] wire1;
	
	assign x = wire1 - 8'd1;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
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
		defparam VGA.BACKGROUND_IMAGE = "initial_screen_colour.mif";
			
	// Outputs x,y,colour and writeEn for the VGA controller
	
		screenState s1(.clk(CLOCK_50), .gs(SW[9]), .go(SW[8]), .X(wire1), .Y(y), .C(colour), 
							.writeEn(writeEn), .userInput(userIn), 
							.MarX(marioX), .MarY(marioY), .BarX(barrelX), .BarY(barrelY));
							
		Animation s2(.ResetN(SW[8]), .K(KEY[3:1]), .CLOCK(CLOCK_50), 
							.vgaX(marioX), .vgaY(marioY));
							
		AnimationB s3(.ResetN(SW[8]), .CLOCK(CLOCK_50), .vgaX(barrelX), .vgaY(barrelY));

//		screenState(.clk(CLOCK_50), .gameStart(SW[9]), .X(x), .Y(y), .C(colour), 
//							.WriteEn(writeEn), .countReset(~KEY[0]));
	
	always@(posedge CLOCK_50)
	begin
		if((KEY[3] == 1'b0)|(KEY[2] == 1'b0)|(KEY[1] == 1'b0)) 
			userIn <= 1'b1;
		else 
			userIn <= 1'b0;
	end

endmodule // fill