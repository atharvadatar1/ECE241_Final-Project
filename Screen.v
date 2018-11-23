`timescale 1ns / 1ns

module screenState(	clk,
							gs,
							go,
							X,
							Y,
							C,
							userInput,
							writeEn,
							MarX,
							MarY,
							BarX,
							BarY
							);
	
input clk, gs, userInput, go;
input [7:0] MarX, BarX;
input [6:0] MarY, BarY;

output [7:0] X;
output [6:0] Y;
output [2:0] C;
output writeEn;

wire 	[2:0] RAMtoOutput1, RAMtoOutput2, RAMtoOutput4, RAMtoOutput5;
wire [7:0] Yout, max_x, max_y;
wire [14:0]counterSS3; 
wire [6:0] counterSS5;
wire [4:0] counterSS6;
wire sEn, mEn, bEn, rstInCounter;
wire [3:0] plot_sig;

assign Y = Yout[6:0];

	// contains the start screen image
	ram19200x3 g1(	.address(counterSS3), 					// from screen_counter
						.clock(clk), 
						.data(3'b0), 
						.wren(1'b0), 
						.q(RAMtoOutput1)
						);
							
	// contains the game_screen image
	ram19200x3_game_screen_final g2(	.address(counterSS3), 		// from screen_counter
												.clock(clk), 
												.data(3'b0), 
												.wren(1'b0), 
												.q(RAMtoOutput2)
												);
	
	// contains the Mario sprite image
	ram81x3_Mario g4(	.address(counterSS5), 
							.clock(clk), 
							.data(3'b0), 
							.wren(1'b0),
							.q(RAMtoOutput4)
							);
							
	ram25x3_barrel g5(.address(counterSS6),
							.clock(clk),
							.data(3'b0),
							.wren(1'b0),
							.q(RAMtoOutput5)
							);
					
	control ss1(.clk(clk),
					.gS(gs),
					.x_count(max_x),
					.y_count(max_y),
					.userInput(userInput),
					.resetInnerCounter(rstInCounter),
					.Screen_enable(sEn),
					.Mario_enable(mEn),
					.Barrel_enable(bEn),
					.screen_count(counterSS3),
					.mario_count(counterSS5),
					.barrel_count(counterSS6),
					.plot(plot_sig),
					.writeEn(writeEn),
					.go(go)
					);
					
	datapath ss2(.RAMtoOutput1(RAMtoOutput1),			// comes from the ram19200x3
					.RAMtoOutput2(RAMtoOutput2),			// comes from ram19200x3_game_screen
					.RAMtoOutput4(RAMtoOutput4),			// comes from ram81x3_mario
					.RAMtoOutput5(RAMtoOutput5),
					.resetInnerCounter(rstInCounter),						// this comes from the control path
					.X_r(X),
					.Y_r(Yout),
					.C_r(C),
					.x_count(max_x),										// will come from the control path
					.y_count(max_y),										// will come from the control path
					.plot(plot_sig),
					.clk(clk),
					.marioX(MarX),
					.marioY(MarY),
					.barrelX(BarX),
					.barrelY(BarY)
					);
				
	Screen_counter ss3(	.clk(clk),
								.resetn(go),
								.Screen_enable(sEn),				// from control
								.screen_count(counterSS3)
								);
								
							
	Mario_counter ss4(.clk(clk),
							.resetn(go),
							.Mario_enable(mEn),					// from the control
							.mario_count(counterSS5)
							);
							
	Barrel_counter ss6(	.clk(clk),
								.resetn(go),
								.Barrel_enable(bEn),
								.barrel_count(counterSS6)
								);
							
endmodule

module control(gS,						// SW[9]
					screen_count,			// from the Screen_counter
					mario_count,			// from the Mario_counter
					barrel_count,
					userInput,				// from the user input on FPGA
					clk,						// CLOCK_50
					x_count,
					y_count,
					resetInnerCounter,
					Screen_enable,
					Mario_enable,
					Barrel_enable,
					plot,
					writeEn,
					go
					);


input clk, gS, userInput, go;
input [14:0] screen_count;
input [6:0] mario_count;
input [4:0] barrel_count;

output reg Screen_enable, Mario_enable, Barrel_enable, writeEn, resetInnerCounter;
output reg [7:0] x_count, y_count;
output reg [3:0] plot;

reg [3:0] current_state, next_state;
	
	// these parameters are for the state diagram
	localparam 	START_SCREEN_WAIT		= 4'd0,
					START_SCREEN			= 4'd1,
					START_SCREEN_DONE		= 4'd2,
				   GAME_SCREEN_WAIT		= 4'd3,
					GAME_SCREEN_DRAW		= 4'd4,
			      DRAW_MARIO_WAIT		= 4'd5,
					DRAW_MARIO				= 4'd6,
					userInput_WAIT			= 4'd7,
					NXT_GAME_S_WAIT		= 4'd8,
					NXT_GAME_S_DRAW		= 4'd9,
					NXT_DRW_MAR_WAIT		= 4'd10,
					NXT_DRW_MAR				= 4'd11,
					NXT_DRW_BAR_WAIT		= 4'd12,
					NXT_DRW_BAR				= 4'd13;

// these parameters define the size of the pixels that need to be replaced in x and y
	
	localparam 	WINDOW_SZ_X 				= 8'd160,				
					WINDOW_SZ_Y					= 8'd120,
					WINDOW_PIX					= 15'd19200,
					MARIO_SZ						= 4'd9,
					MARIO_PIX					= 7'd81,
					BARREL_SZ					= 3'd5,
					BARREL_PIX					= 5'd25;
					
// state table
	always@(*)
	begin
	
		case(current_state)
		
				START_SCREEN_WAIT: 			begin
														
														if (go == 1'b1) // added conditions
															next_state = START_SCREEN;
														else 
															next_state = START_SCREEN_WAIT;
													end
													
				START_SCREEN: 					begin
				
														if (screen_count > WINDOW_PIX)
															next_state = START_SCREEN_DONE;
														else
															next_state = START_SCREEN;
														
													end
													
				START_SCREEN_DONE:			begin
				
														if (gS == 1'b1)
															next_state = GAME_SCREEN_WAIT;
														else 
															next_state = START_SCREEN_DONE;
															
													end
													
				GAME_SCREEN_WAIT:				begin
										
															next_state = GAME_SCREEN_DRAW;
										
													end
													
				GAME_SCREEN_DRAW: 			begin
				
														if (screen_count > WINDOW_PIX)
															next_state = DRAW_MARIO_WAIT;
														else
															next_state = GAME_SCREEN_DRAW;
													end
													
				DRAW_MARIO_WAIT:				begin
														 
															next_state = DRAW_MARIO;
													
													end
				
				DRAW_MARIO: 					begin
				
														if (mario_count > MARIO_PIX)
															next_state = userInput_WAIT;
														else 
															next_state = DRAW_MARIO;
													end
				
				userInput_WAIT:				begin
				
														if (userInput == 1'b1)
															next_state = NXT_GAME_S_WAIT;
														else 
															next_state = userInput_WAIT;
															
													end	
													
				NXT_GAME_S_WAIT:				begin
				
														next_state = NXT_GAME_S_DRAW;
														
													end
													
				NXT_GAME_S_DRAW:				begin
				
														if (screen_count > WINDOW_PIX)
															next_state = NXT_DRW_MAR_WAIT;
														else
															next_state = NXT_GAME_S_DRAW;
															
													end
													
				NXT_DRW_MAR_WAIT:				begin
				
														next_state = NXT_DRW_MAR;
														
													end
													
				NXT_DRW_MAR:						begin
				
														if (mario_count > MARIO_PIX)
															next_state = NXT_DRW_BAR_WAIT;
														else 
															next_state = NXT_DRW_MAR;
															
													end
													
				NXT_DRW_BAR_WAIT:				begin
				
														next_state = NXT_DRW_BAR;
														
													end
													
				NXT_DRW_BAR:						begin
				
														if (barrel_count > BARREL_PIX)
															next_state = NXT_GAME_S_WAIT;
														else
															next_state = NXT_DRW_BAR;
															
													end
													
				default: next_state = START_SCREEN_WAIT;
		endcase
	end
	
	always@(*)
	begin
			
		// all signals are initialised to 0
		x_count = 8'b0;
		y_count = 8'b0;
		plot = 4'd0;
		Screen_enable = 1'b0;
		Mario_enable = 1'b0;
		Barrel_enable = 1'b0;
		writeEn = 1'b0;
		resetInnerCounter = 1'b0;
		
		case(current_state)
		
			START_SCREEN_WAIT: 				begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd0;			// changed this to zero		
														Screen_enable = 1'b0;	// changed this to zero
														Mario_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
													
			START_SCREEN: 						begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd1;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
													
			START_SCREEN_DONE:				begin
														x_count = 8'd0;
															y_count = 8'd0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end	
				
													
			GAME_SCREEN_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
													
			GAME_SCREEN_DRAW:		 			begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
													
			DRAW_MARIO_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
				
			DRAW_MARIO: 						begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
				
			userInput_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end	
													
			NXT_GAME_S_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
													
			NXT_GAME_S_DRAW:					begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
													
			NXT_DRW_MAR_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
													
			NXT_DRW_MAR:							begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
													
			NXT_DRW_BAR_WAIT:					begin
														x_count = 8'd0;
														y_count = 8'd0;
														plot = 4'd5;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b1;
														writeEn = 1'b0;
														resetInnerCounter = 1'b1;
													end
													
			NXT_DRW_BAR:						begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd5;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b1;
														writeEn = 1'b1;
														resetInnerCounter = 1'b0;
													end
													
		endcase
	end
	
	always@(posedge clk)
	begin
		if (go == 1'b0)
			current_state <= START_SCREEN_WAIT;
		else
			current_state <= next_state;
	end
	
endmodule

module datapath (	RAMtoOutput1,
						RAMtoOutput2,
						RAMtoOutput4,
						RAMtoOutput5,
						resetInnerCounter,
						X_r,
						Y_r,
						C_r,
						x_count,
						y_count,
						plot,
						clk,
						marioX,
						marioY,
						barrelX,
						barrelY
						);
	
	input [2:0] RAMtoOutput1, RAMtoOutput2, RAMtoOutput4, RAMtoOutput5;
	input resetInnerCounter, clk;
	input [7:0] x_count, y_count;
	input [3:0] plot;
	input [7:0] marioX, barrelX;
	input [6:0] marioY, barrelY;
	
	wire [7:0] MarY;
	assign MarY = {1'b0, marioY};
	
	wire [7:0] BarY;
	assign BarY = {1'b0, barrelY};
	
	output reg [7:0] X_r, Y_r;
	output reg [2:0] C_r;
	
	reg [7:0] X, Y, X_mar, Y_mar, X_bar, Y_bar, count_x, count_y;
	reg [2:0] C, C_mar, C_bar;
	
//	wire [15:0] ordinateToAddress;
//	assign ordinateToAddress = ({1'b0, Y_r[6:0], 7'd0} + {1'b0, Y_r[6:0], 5'd0} + {1'b0, X_r});
//	wire [14:0] VGAtoRAM1;
//	assign VGAtoRAM1 = ordinateToAddress[14:0];

	
	always@(posedge clk)
		begin
			if (resetInnerCounter == 1'b1) // resetCounter will come from the contro path, reset this in the wait states
			begin
				X_r <= 8'b0;
				Y_r <= 8'b0;
				C_r <= 3'b0;
				X <= 8'b0;
				Y <= 8'b0;
				C <= 8'b0;
				X_mar <= 8'b0;
				Y_mar <= 8'b0;
				C_mar <= 3'b0;
				X_bar <= 8'd0;
				Y_bar <= 8'd0;
				C_bar <= 3'd0;
			end
			
			else
			begin
				if (plot == 4'd1)
				begin
					X <= 8'b0;
					Y <= 8'b0;
					C <= RAMtoOutput1;
					X_r <= X;
					Y_r <= Y;
					C_r <= C;
				end
				
				else if (plot == 4'd2)
				begin
					X <= 8'b0;
					Y <= 8'b0;
					C <= RAMtoOutput2;
					X_r <= X;
					Y_r <= Y;
					C_r <= C;
				end
				
				else if (plot == 4'd4)
				begin
					X_mar <= marioX;
					Y_mar <= MarY;
					C_mar <= RAMtoOutput4;
					X_r <= X_mar;
					Y_r <= Y_mar;
					C_r <= C_mar;
				end
				
				else if (plot == 4'd5)
				begin
					X_bar <= barrelX;
					Y_bar <= BarY;
					C_bar <= RAMtoOutput5;
					X_r	<= X_bar;
					Y_r 	<= Y_bar;
					C_r 	<= C_bar;
				end
			end
			
			if (resetInnerCounter == 1'b0)
			begin
				if ((count_x == (x_count - 1'd1)) & (x_count > 8'd0))
				begin
					count_x <= 8'd0;
					count_y <= count_y + 1'b1;
				end
				
				else if (x_count >= 8'd0) // shoud this be greater than - equal or just greater
				begin
					count_x <= count_x + 1'b1;
				end
				
				if ((count_y == (y_count - 1'b1)) & (count_x == (x_count - 1'b1)) 
					& (y_count > 8'd0))
				begin
					count_y <= 8'd0;
				end
			end
			
			else 
			begin
				count_x <= 8'd0;
				count_y <= 8'd0;
			end
			
			if (plot == 4'd4) begin
				X_r <= X_mar + count_x;
				Y_r <= Y_mar + count_y;
			end 
			
			else if (plot == 4'd5) begin
				X_r <= X_bar + count_x;
				Y_r <= Y_bar + count_y;
			end
			
			else begin
				X_r <= X + count_x;
				Y_r <= Y + count_y;
			end	
		end
endmodule

// the counter module for drawing the entire screen onto the monitor
module Screen_counter(clk, resetn, Screen_enable, screen_count);

	input clk, resetn, Screen_enable;
	output reg [14:0] screen_count;
	
	always@(posedge clk)
	begin
		if (!resetn) begin
			screen_count <= 15'd0;
		end
		
		else begin 
		
			if (screen_count > 15'd19200) begin
				screen_count <= 15'd0;
			end
			
			else if (Screen_enable) begin
				screen_count <= screen_count + 1;
			end
			
			else 
				screen_count <= screen_count;
		end
	end
endmodule 

// the counter module for drawing the mario sprite onto the screen
module Mario_counter(clk, resetn, Mario_enable, mario_count);

	input clk, resetn, Mario_enable;
	output reg [6:0] mario_count;
	
	always@(posedge clk)
	begin
		if (!resetn) begin
			mario_count <= 7'd0;
		end
		
		else if (mario_count > 7'd81) begin
			mario_count <= 7'd0;
		end
		
		else if (Mario_enable) begin
			mario_count <= mario_count + 1;
		end
		
		else 
			mario_count <= mario_count;
	end
			
endmodule 

module Barrel_counter(clk, resetn, Barrel_enable, barrel_count);

	input clk, resetn, Barrel_enable;
	output reg [4:0] barrel_count;
		
		always@(posedge clk)
		begin
			if (!resetn) begin
				barrel_count <= 5'd0;
			end
			
			else if (barrel_count > 5'd25) begin
				barrel_count <= 5'd0;
			end
			
			else if (Barrel_enable) begin
				barrel_count <= barrel_count + 1'b1;
			end
			
			else 
				barrel_count <= barrel_count;
		end
				
endmodule 
