// Created by Dhruv Patel
// Final Demo (Barrel Module)

/*
    TO MOVE WITHIN THE GAME USING THE K INPUT, USE THE FOLLOWING 
    TABLE. 
    MOVE UP: 0001
    MOVE RIGHT: 0010 
    MOVE LEFT: 0100
    JUMP: 1000
    MOVE DOWN: 1100 
*/

module BarrelAnimation(
    input ResetN, 
    input CLOCK,  
    output[7:0] vgaX, 
    output[6:0] vgaY 
); 

    wire [2:0] f_d; 
    wire [3:0] count; 
    wire dN, sU, sR, sL, sS, sD, start; 
    
    wire [25:0] Qout; 
    wire enable;
    EnableSignalB ES1(.ResetN(ResetN), .Clk(CLOCK), .Q(Qout)); 
    assign enable = (Qout == 26'd0) ? 1'b1 : 1'b0; // Currently, the animation is set to 32 Hz
    
    wire[7:0] currentX; 
    wire[6:0] currentY; 
    CurrentPosition CP1(.ResetN(ResetN), .Clk(CLOCK), .vgaX(vgaX), .vgaY(vgaY), .Xout(currentX), .Yout(currentY));  

    BarrelRoll BR1 (.currentX(currentX), .currentY(currentY), .ResetN(ResetN), .Clk(CLOCK), .enableSignal(enable), .f_d(f_d)); 
 
    ControlDraw2 CD2(.f_d(f_d), .enableSignal(enable), .Clk(CLOCK), .ResetN(ResetN), .doNothing(dN), .sUp(sU), .sRight(sR), .sLeft(sL), .sDown(sD), .sSpace(sS), .sStart(start),
                     .cX(currentX), .cY(currentY));
    DatatPath2 DP1(.doNothing(dN), .sUp(sU), .sRight(sR), .sLeft(sL), .sDown(sD), .sSpace(sS), .Clk(CLOCK), .ResetN(ResetN), .X(currentX), .Y(currentY),
                 .counter(count), .FinalX(vgaX), .FinalY(vgaY), .sStart(start));
endmodule // main

module BarrelRoll(
    input[7:0] currentX, 
    input[6:0] currentY, 
    input ResetN, 
    input Clk, 
    input enableSignal, 
    output reg[2:0] f_d 
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            f_d <= 3'b000;
        else if(enableSignal == 1'b1) begin
            if((currentX < 8'd160 -  8'd5) && (currentY == 7'd40 || currentY == 7'd88))  // Right
                f_d = 3'b010; 
            else if((currentX > 8'd0) && (currentY == 7'd16 || currentY == 7'd64 || currentY == 7'd113)) // Left
                f_d = 3'b011; 
            else if((currentX == 8'd0) && ((currentY >= 7'd64 && currentY < 7'd88) || (currentY >= 7'd16 && currentY < 7'd40)))  // Down
                f_d = 3'b101; 
            else if((currentX == 8'd155) && ((currentY >= 7'd88 && currentY < 7'd113) || (currentY >= 7'd40 && currentY < 7'd64)))  // Down 
                f_d = 3'b101;
            else 
                f_d = 3'b000;
        end
        else 
            f_d <= 3'b000;
    end
endmodule

module EnableSignalB(
    input ResetN, 
    input Clk, 
    output reg[25:0] Q
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            Q <= 26'b00000101111101011110000011;
        else if(Q == 0) 
            Q <= 26'b00000101111101011110000011; // Animation speed is 32 Hz
        else 
            Q <= Q - 1'b1; 
    end
endmodule 

module CurrentPositionB(
    input ResetN, 
    input Clk, 
    input[7:0] vgaX, 
    input[6:0] vgaY, 
    output reg[7:0] Xout, 
    output reg[6:0] Yout
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) begin
          Xout <= 8'd133; 
          Yout <= 7'd16; 
        end
        else begin
          Xout <= vgaX; 
          Yout <= vgaY;  
        end 
    end 
endmodule

module ControlDraw2(
    input[7:0] cX, 
    input[6:0] cY,
    input[2:0] f_d,   
    input enableSignal,
    input Clk, 
    input ResetN, 
    output reg doNothing, sUp, sRight, sLeft, sDown, sSpace, sStart
); 
   reg[2:0] currentState; 
   reg[2:0] nextState; 
   localparam START = 3'b000, 
               SHIFT_UP = 3'b001, 
               SHIFT_RIGHT = 3'b010, 
               SHIFT_LEFT = 3'b011,
               SHIFT_SPACE = 3'b100, 
               SHIFT_DOWN = 3'b101,
	       DONE = 3'b110;  
	always @(*)
	begin: FSM_2
	  case (currentState)
	     START: if(f_d == 3'b000)
			           nextState = START; 
		          else if(f_d == 3'b001)
			           nextState = SHIFT_UP; 
		          else if(f_d == 3'b010)
			           nextState = SHIFT_RIGHT;
                  else if(f_d == 3'b011)
                       nextState = SHIFT_LEFT; 
                  else if(f_d == 3'b100)
			           nextState = SHIFT_SPACE; 
		          else if(f_d == 3'b101)
			           nextState = SHIFT_DOWN; 
		          else
			           nextState = START;
	     SHIFT_UP: nextState = (f_d == 3'b001) ? DONE : START;
	     SHIFT_RIGHT: nextState = (f_d == 3'b010) ? DONE : START; 
	     SHIFT_LEFT: nextState = (f_d == 3'b011) ? DONE : START; 
	     SHIFT_SPACE: nextState = (f_d == 3'b100) ? DONE : START; 
	     SHIFT_DOWN: nextState = (f_d == 3'b101) ? DONE : START; 
	     DONE: nextState = enableSignal ? START : DONE; 
	     default: nextState = START; 
    endcase
  end
    always @(*) 
    begin: Enable_Signals
      doNothing = 1'b0; 
	    sUp = 1'b0; 
	    sRight = 1'b0;
	    sLeft = 1'b0;
      sSpace = 1'b0; 
      sDown = 1'b0;
      sStart = 1'b0; 
      case(currentState) 
          START: begin
              if(cX >= 8'd0 && cX <= 8'd5 && cY >= 7'd112)
                sStart = 1'b1;
              else
                doNothing = 1'b1;  
          end
          SHIFT_UP:
              sUp = 1'b1; 
          SHIFT_RIGHT:
              sRight = 1'b1; 
          SHIFT_LEFT:
              sLeft = 1'b1; 
          SHIFT_SPACE:
              sSpace = 1'b1; 
          SHIFT_DOWN:
              sDown = 1'b1;
	        DONE:
		          doNothing = 1'b1;
      endcase
    end
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            currentState <= START; 
        else
            currentState <= nextState; 
    end
endmodule // ControlDraw2


module DatatPath2 (
    input doNothing, sUp, sRight, sLeft, sDown, sSpace, sStart,  
    input Clk, 
    input ResetN, 
    input[7:0] X, 
    input[6:0] Y,
    input[3:0] counter,
    output reg[7:0] FinalX,
    output reg[6:0] FinalY
); 
    always @(posedge Clk)
    begin
	     if(!ResetN) begin
		      FinalX <= 8'd133; 
              FinalY <= 7'd16; 
	     end
	     if(sUp) begin
		      FinalX <= X;  
		      FinalY <= Y - 1'b1; 
	     end
	     if(sRight) begin
		      FinalX <= X + 1'b1; 
		      FinalY <= Y; 
	     end 
	     if(sLeft) begin
		      FinalX <= X - 1'b1; 
		      FinalY <= Y; 
	     end
	     if(sSpace) begin 
          if(counter <= 4'b0100) begin  
              FinalX <= X; 
              FinalY <= Y - 1'b1; 
          end 
          else if(counter > 4'b0100) begin 
              FinalX <= X; 
              FinalY <= Y + 1'b1; 
          end 
	     end
	     if(sDown) begin
		      FinalX <= X; 
		      FinalY <= Y + 1'b1; 
	     end
         if(sStart) begin
            FinalX <= 8'd133; 
            FinalY <= 7'd16; 
         end
    end     
endmodule // DatatPath2