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

wire 	[2:0] RAMtoOutput1, RAMtoOutput2, RAMtoOutput3, RAMtoOutput4;
wire [7:0] Yout, max_x, max_y;
wire [14:0] counter_ss33, counter_ss6; 
wire [6:0] counter_ss4, counter_ss7;
wire [5:0] counter_ss5, counter_ss8;

wire sEn, mEn, bEn, rstCounters, sEnable, mEnable, bEnable;
wire [3:0] plot_sig;

assign Y = Yout[6:0];

	// contains the start screen image
	ram19200x3 g1(	.address(counter_ss3), 					// from screen_counter
						.clock(clk), 
						.data(3'b0), 
						.wren(1'b0), 
						.q(RAMtoOutput1)
						);
							
	// contains the game_screen image
	ram19200x3_game_screen_final g2(	.address(counter_ss3), 		// from screen_counter
												.clock(clk), 
												.data(3'b0), 
												.wren(1'b0), 
												.q(RAMtoOutput2)
												);
	
	// contains the Mario sprite image
	ram81x3_Mario g4(	.address(counter_ss4), 
							.clock(clk), 
							.data(3'b0), 
							.wren(1'b0),
							.q(RAMtoOutput3)
							);
							
	ram25x3_barrel g3(.address(counter_ss5),
							.clock(clk),
							.data(3'b0),
							.wren(1'b0),
							.q(RAMtoOutput4)
							);
					
	control ss1(.clk(clk),
					.gS(gs),
					.x_count(max_x),
					.y_count(max_y),
					.userInput(userInput),
					.resetCounters(rstCounters),
					.Screen_enable(sEn),
					.Mario_enable(mEn),
					.Barrel_enable(bEn),
					.s_enable(sEnable),
					.m_enable(mEnable),
					.b_enable(bEnable),
					.scount(counter_ss6),
					.mcount(counter_ss7),
					.bcount(counter_ss8),
					.plot(plot_sig),
					.writeEn(writeEn),
					.go(go)
					);
					
	datapath ss2(.RAMtoOutput1(RAMtoOutput1),			// comes from the ram19200x3
					.RAMtoOutput2(RAMtoOutput2),			// comes from ram19200x3_game_screen
					.RAMtoOutput3(RAMtoOutput3),			// comes from ram81x3_mario
					.RAMtoOutput4(RAMtoOutput4),
					.resetCounters(rstCounters),						// this comes from the control path
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
								.resetn(rstCounters),
								.Screen_enable(sEn),				// from control
								.screen_count(counter_ss3)
								);
								
							
	Mario_counter ss4(.clk(clk),
							.resetn(rstCounters),
							.Mario_enable(mEn),					// from the control
							.mario_count(counter_ss4)
							);
						
	Barrel_counter ss5(	.clk(clk),
								.resetn(rstCounters),
								.Barrel_enable(bEn),
								.barrel_count(counter_ss5)
							);
							
	State_screen_counter ss6(	.clk(clk),
										.resetn(rstCounters),
										.s_enable(sEnable),
										.scount(counter_ss6)
										);
	
	State_mario_counter ss7(	.clk(clk),
										.resetn(rstCounters),
										.m_enable(mEnable),
										.mcount(counter_ss7)
										);
										
	State_barrel_count ss8(	.clk(clk),
									.resetn(rstCounters),
									.b_enable(bEnable),
									.bcount(counter_ss8)
									);
									
endmodule

module control(gS,						// SW[9]
					scount,			// from the Screen_counter
					mcount,			// from the Mario_counter
					bcount,
					userInput,				// from the user input on FPGA
					clk,						// CLOCK_50
					x_count,
					y_count,
					resetCounters,
					Screen_enable,
					Mario_enable,
					Barrel_enable,
					s_enable,
					m_enable,
					b_enable,
					plot,
					writeEn,
					go
					);


input clk, gS, userInput, go;
input [14:0] scount;
input [6:0] mcount;
input [4:0] bcount;

output reg Screen_enable, Mario_enable, Barrel_enable, writeEn, resetCounters;
output reg s_enable, m_enable, b_enable;
output reg [7:0] x_count, y_count;
output reg [3:0] plot;

reg [3:0] current_state, next_state;
	
	// these parameters are for the state diagram
	localparam 	START_SCREEN_WAIT		= 5'd0,
					START_SCREEN			= 5'd1,
					START_SCREEN_DONE		= 5'd2,
				   GAME_SCREEN_WAIT		= 5'd3,
					GAME_SCREEN_DRAW		= 5'd4,
					GAME_SCREEN_DONE		= 5'd5,
			      DRAW_MARIO_WAIT		= 5'd6,
					DRAW_MARIO				= 5'd7,
					userInput_WAIT			= 5'd8,
					BARREL_DRAW_WAIT		= 5'd9,
					BARREL_DRAW				= 5'd10,
					BARREL_DONE				= 5'd11,
					BARREL_ERASE_WAIT		= 5'd12,
					BARREL_ERASE			= 5'd13,
					BARREL_ERASE_DONE		= 5'd14,
					MAR_DRAW_WAIT			= 5'd15,
					MAR_DRAW					= 5'd16,
					MAR_DONE					= 5'd17,
					MAR_ERASE_WAIT			= 5'd18,
					MAR_ERASE				= 5'd19,
					MAR_ERASE_DONE			= 5'd20;

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
														
														if (go == 1'b1)                // added conditions
															next_state = START_SCREEN;
														else 
															next_state = START_SCREEN_WAIT;
													end
													
				START_SCREEN: 					begin
				
														if (scount > WINDOW_PIX)
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
				
														if (scount > WINDOW_PIX)
															next_state = GAME_SCREEN_DONE;
														else
															next_state = GAME_SCREEN_DRAW;
													end
													
				GAME_SCREEN_DONE:				begin
				
														next_state = DRAW_MARIO_WAIT;
															
													end
													
				DRAW_MARIO_WAIT:				begin
														 
														next_state = DRAW_MARIO;
													
													end
				
				DRAW_MARIO: 					begin
				
														if (mcount > MARIO_PIX)
															next_state = userInput_WAIT;
														else 
															next_state = DRAW_MARIO;
													end
				
				userInput_WAIT:				begin
				
														if (userInput == 1'b1)
															next_state = BARREL_DRAW_WAIT;
														else 
															next_state = userInput_WAIT;
															
													end	
												
				BARREL_DRAW_WAIT:				begin
				
														next_state = BARREL_DRAW;
														
													end
													
				BARREL_DRAW:					begin
				
														if (bcount > BARREL_PIX)
															next_state = BARREL_DONE;
														else 
															next_state = BARREL_DRAW;
															
													end
													
				BARREL_DONE:					begin
				
														next_state = BARREL_ERASE_WAIT;
														
													end
													
				BARREL_ERASE_WAIT:			begin
				
														next_state = BARREL_ERASE;
														
													end
													
				BARREL_ERASE:					begin
				
														if (bcount > BARREL_PIX)
															next_state = BARREL_ERASE_DONE;
														else 
															next_state = BARREL_ERASE;
															
													end
													
				BARREL_ERASE_DONE:			begin
				
														next_state = MAR_DRAW_WAIT;
															
													end
													
				MAR_DRAW_WAIT:					begin
								
														next_state = MAR_DRAW;
														
													end
													
				MAR_DRAW:						begin
				
														if (mcount > MARIO_PIX)
															next_state = MAR_DONE;
														else 
															next_state = MAR_DRAW;
															
													end
													
				MAR_DONE:						begin
					
														next_state = MAR_ERASE_WAIT;
														
													end
													
				MAR_ERASE_WAIT:				begin
				
														next_state = MAR_ERASE;
														
													end
													
				MAR_ERASE:						begin
				
														if (mcount > MARIO_PIX)
															next_state = MAR_ERASE_DONE;
														else 
															next_state = MAR_ERASE;
															
													end
													
				MAR_ERASE_DONE:				begin
				
														next_state = BARREL_DRAW_WAIT;
														
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
		s_enable = 1'b0;
		m_enable = 1'b0;
		b_enable = 1'b0;
		writeEn = 1'b0;
		resetCounters = 1'b1;
		
		case(current_state)
		
			START_SCREEN_WAIT: 				begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd1;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
													
			START_SCREEN: 						begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd1;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b1;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
													
			START_SCREEN_DONE:				begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end	
				
			GAME_SCREEN_WAIT:					begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
													
			GAME_SCREEN_DRAW:		 			begin
														x_count = WINDOW_SZ_X;
														y_count = WINDOW_SZ_Y;
														plot = 4'd2;
														Screen_enable = 1'b1;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b1;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
													
			GAME_SCREEN_DONE:					begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end
													
			DRAW_MARIO_WAIT:					begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd3;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
				
			DRAW_MARIO: 						begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd3;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b1;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
				
			userInput_WAIT:					begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end	
			
			BARREL_DRAW_WAIT:					begin
														x_count = BARREL_SZ;
														y_count = BARREL_SZ;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b1;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
												
			BARREL_DRAW:						begin
														x_count = BARREL_SZ;
														y_count = BARREL_SZ;
														plot = 4'd4;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b1;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b1;
														writeEn = 1'b1;
														resetCounters = 1'b0;	
													end
												
			BARREL_DONE:						begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd5;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end
													
			BARREL_ERASE_WAIT:				begin
														x_count = BARREL_SZ;
														y_count = BARREL_SZ;
														plot = 4'd5;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
												
			BARREL_ERASE:						begin
														x_count = BARREL_SZ;
														y_count = BARREL_SZ;
														plot = 4'd5;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b1;
														writeEn = 1'b1;
														resetCounters = 1'b0;	
													end
													
			BARREL_ERASE_DONE:				begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end
												
			MAR_DRAW_WAIT:						begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd3;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
												
			MAR_DRAW:							begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd3;
														Screen_enable = 1'b0;
														Mario_enable = 1'b1;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b1;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
												
			MAR_DONE:							begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd6;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
													end
													
			MAR_ERASE_WAIT:					begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd6;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;
													end
												
			MAR_ERASE:							begin
														x_count = MARIO_SZ;
														y_count = MARIO_SZ;
														plot = 4'd6;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b1;
														b_enable = 1'b0;
														writeEn = 1'b1;
														resetCounters = 1'b0;	
													end
													
			MAR_ERASE_DONE:					begin
														x_count = 8'b0;
														y_count = 8'b0;
														plot = 4'd0;
														Screen_enable = 1'b0;
														Mario_enable = 1'b0;
														Barrel_enable = 1'b0;
														s_enable = 1'b0;
														m_enable = 1'b0;
														b_enable = 1'b0;
														writeEn = 1'b0;
														resetCounters = 1'b1;
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
						RAMtoOutput3,
						RAMtoOutput4,
						resetCounters,
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
	
	input [2:0] RAMtoOutput1, RAMtoOutput2, RAMtoOutput3, RAMtoOutput4;
	input resetCounters, clk;
	input [7:0] x_count, y_count;
	input [3:0] plot;
	input [7:0] marioX, barrelX;
	input [6:0] marioY, barrelY;
	
	wire [7:0] MarY;
	assign MarY = {1'b0, marioY};
	
	wire [7:0] BarY;
	assign BarY = {1'b0, barrelY};
	
	wire [2:0] RAMtoOutput5;
	
	output reg [7:0] X_r, Y_r;
	output reg [2:0] C_r;
	
	reg [7:0] X, Y, X_mar, Y_mar, count_x, count_y, X_bar, Y_bar;
	reg [2:0] C, C_mar, C_bar;
	
	wire [15:0] ordinateToAddress;
	assign ordinateToAddress = ({1'b0, Y_r[6:0], 7'd0} + {1'b0, Y_r[6:0], 5'd0} + {1'b0, X_r});
	wire [14:0] VGAtoRAM1;
	assign VGAtoRAM1 = ordinateToAddress[14:0];
	
	ram19200x3_game_screen_final g2(	.address(ordinateToAddress), 		// from screen_counter
												.clock(clk), 
												.data(3'b0), 
												.wren(1'b0), 
												.q(RAMtoOutput5)
												);
	
	always@(posedge clk)
		begin
			if (resetCounters == 1'b1) // resetCounter will come from the contro path, reset this in the wait states
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
			end
			
			else
			begin
				if (plot == 4'd1)
				begin
					/*X <= 8'b0;
					Y <= 8'b0;
					C <= RAMtoOutput1;*/
					X_r <= 8'd0 + count_x;
					Y_r <= 8'd0 + count_y;
					C_r <= RAMtoOutput1;
				end
				
				else if (plot == 4'd2)
				begin
					/*X <= 8'b0;
					Y <= 8'b0;
					C <= RAMtoOutput2;*/
					X_r <= 8'd0 + count_x;
					Y_r <= 8'd0 + count_y;
					C_r <= RAMtoOutput2;
				end
				
				else if (plot == 4'd3)
				begin
					/*X_mar <= marioX;
					Y_mar <= MarY;
					C_mar <= RAMtoOutput3;*/
					X_r <= marioX + count_x;
					Y_r <= MarY + count_y;
					C_r <= RAMtoOutput3;
				end
				
				else if (plot == 4'd4)
				begin
					/*X_bar <= barrelX;
					Y_bar <= barrelY;
					C_bar <= RAMtoOutput4;*/
					X_r <= barrelX + count_x;
					Y_r <= BarY + count_y;
					C_r <= RAMtoOutput4;
				end
				
				else if (plot == 4'd5)
				begin
					X_r <= barrelX + count_x;
					Y_r <= BarY + count_y;
					C_r <= RAMtoOutput5;
				end
				
				else if (plot == 4'd6)
				begin
					X_r <= marioX + count_x;
					Y_r <= MarY + count_y;
					C_r <= RAMtoOutput5;
				end
			end
			
			if (resetCounters == 1'b0)
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
			else	begin
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
		if (resetn) begin
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
		if (resetn) begin
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
			if (resetn) begin
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

module State_screen_counter(clk, resetn, scount, s_enable);

	input clk, resetn, s_enable;
	output reg [14:0] scount;
	
	always@(posedge clk)
	begin
		if (resetn) begin
			scount <= 15'd0;
		end
		
		else begin 
		
			if (scount > 15'd19200) begin
				scount <= 15'd0;
			end
			
			else if (s_enable) begin
				scount <= scount + 1;
			end
			
			else 
				scount <= scount;
		end
	end
endmodule 

module State_mario_counter(clk, resetn, mcount, m_enable);

	input clk, resetn, m_enable;
	output reg [6:0] mcount;
	
	always@(posedge clk)
	begin
		if (resetn) begin
			mcount <= 7'd0;
		end
		
		else if (mcount > 7'd81) begin
			mcount <= 7'd0;
		end
		
		else if (m_enable) begin
			mcount <= mcount + 1;
		end
		
		else 
			mcount <= mcount;
	end
			
endmodule 

module State_barrel_count(clk, resetn, bcount, b_enable);

	input clk, resetn, b_enable;
	output reg [4:0] bcount;
		
		always@(posedge clk)
		begin
			if (resetn) begin
				bcount <= 5'd0;
			end
			
			else if (bcount > 5'd25) begin
				bcount <= 5'd0;
			end
			
			else if (b_enable) begin
				bcount <= bcount + 1'b1;
			end
			
			else 
				bcount <= bcount;
		end
				
endmodule 
