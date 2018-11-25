// Created by Dhruv Patel
// Final Demo (Move Module)

/*
    TO MOVE WITHIN THE GAME USING THE K INPUT, USE THE FOLLOWING 
    TABLE. 
    MOVE UP: 0001
    MOVE RIGHT: 0010 
    MOVE LEFT: 0100
    JUMP: 1000
    MOVE DOWN: 1100 
*/

module Animation(
    input ResetN, 
    input[2:0] K, 
    input CLOCK,  
    output[7:0] vgaX, 
    output[6:0] vgaY
); 

    wire [2:0] f_d; 
    wire [4:0] count; 
    wire dN, sU, sR, sL, sS, sD; 
    
    wire [25:0] Qout; 
    wire enable;
    EnableSignal ES1(.ResetN(ResetN), .Clk(CLOCK), .Q(Qout)); 
    assign enable = (Qout == 26'd0) ? 1'b1 : 1'b0; // Currently, the animation is set to 16 Hz
    
    wire[7:0] currentX; 
    wire[6:0] currentY; 
    CurrentPosition CP1(.ResetN(ResetN), .Clk(CLOCK), .vgaX(vgaX), .vgaY(vgaY), .Xout(currentX), .Yout(currentY)); 

    ControlCommand CC1(.Direction(K), .currentX(currentX), .currentY(currentY), .Width(8'd160), .Height(7'd120), .Clk(CLOCK), .ResetN(ResetN), .enableSignal(enable),
	           .FinalD(f_d), .counter(count));  
    ControlDraw CD2(.f_d(f_d), .enableSignal(enable), .Clk(CLOCK), .ResetN(ResetN), .doNothing(dN), .sUp(sU), .sRight(sR), .sLeft(sL), .sDown(sD), .sSpace(sS));
    DataPath DP1(.doNothing(dN), .sUp(sU), .sRight(sR), .sLeft(sL), .sDown(sD), .sSpace(sS), .Clk(CLOCK), .ResetN(ResetN), .X(currentX), .Y(currentY),
                 .counter(count), .FinalX(vgaX), .FinalY(vgaY));
	//HEX H1(.B({1'b0,f_d}), .S(HEX));
endmodule // main

module EnableSignal(
    input ResetN, 
    input Clk, 
    output reg[25:0] Q
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            Q <= 26'b00001011111010111100000111;
        else if(Q == 0) 
            Q <= 26'b00001011111010111100000111; // Animation speed is 16 Hz
        else 
            Q <= Q - 1'b1; 
    end
endmodule 

module CurrentPosition(
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
          Xout <= 8'd0; 
          Yout <= 7'd109; 
        end
        else begin
          Xout <= vgaX; 
          Yout <= vgaY;  
        end 
    end 
endmodule

module ControlCommand(
    input[2:0] Direction, 
    input[7:0] currentX,  
    input[6:0] currentY, 
    input[7:0] Width, 
    input[6:0] Height,
    input Clk, 
    input ResetN, 
    input enableSignal, 
    output reg[2:0] FinalD, 
    output reg[4:0] counter
); 
    wire enable; 
    reg[2:0] currentState; 
    reg[2:0] nextState; 
    localparam S_GetCommand = 3'b000, 
               S_UP = 3'b001, 
               S_RIGHT = 3'b010, 
               S_LEFT = 3'b011,
               S_SPACE = 3'b100, 
               S_DOWN = 3'b101,
               S_WAIT = 3'b110,
			   S_SPACE_WAIT = 3'b111;
    always @(posedge Clk) 
    begin: SpaceCounter
        if(!ResetN == 1'b1 || enable == 1'b1)
            counter <= 5'd17; 
        else if(enableSignal == 1'b1 && nextState == S_SPACE_WAIT)
            counter <= counter - 1'b1; 
	    else 
	        counter <= counter;
    end
    assign enable = (counter == 5'd0) ? 1'b1 : 1'b0;  // Make height Mario can jump is 9 pixels 
    always @(*)
    begin: FSM_1
        case (currentState)
            S_GetCommand: if(Direction == 3'b110)
                            nextState = S_UP; 
                          else if(Direction == 3'b101)
                            nextState = S_RIGHT;
                          else if(Direction == 3'b011)
                            nextState = S_LEFT;
                          else if(Direction == 3'b000)
                            nextState = S_SPACE;
                          else if(Direction == 3'b001)
                            nextState = S_DOWN;
                          else
                            nextState = S_WAIT; 
            S_UP: nextState = (Direction == 3'b110) ? S_UP : S_WAIT; 
            S_RIGHT: nextState = (Direction == 3'b101) ? S_RIGHT : S_WAIT; 
            S_LEFT: nextState = (Direction == 3'b011) ? S_LEFT : S_WAIT; 
            S_SPACE: nextState = S_SPACE_WAIT;
			S_SPACE_WAIT: nextState = enable ? S_WAIT : S_SPACE_WAIT; 
            S_DOWN: nextState = (Direction == 3'b001) ? S_DOWN : S_WAIT;
            S_WAIT: nextState = enableSignal ? S_GetCommand : S_WAIT; 
            default: nextState = S_GetCommand;
        endcase
    end
    always @(*) 
    begin: Enable_Signals
        case(currentState)
            S_GetCommand: 
                FinalD = 3'b000; 
            S_UP:
                if((currentX <= 8'd9) && ((currentY > 7'd60 && currentY <= 7'd84) || (currentY > 7'd12 && currentY <= 7'd36)))  
                    FinalD = 3'b001; 
                else if((currentX >= 8'd150) && ((currentY > 7'd84 && currentY <= 7'd109) || (currentY > 7'd36 && currentY <= 7'd60)))  
                    FinalD = 3'b001;
                else if((currentX >= 8'd125 && currentX <= 8'd134) && (currentY > 7'd0 && currentY <= 7'd12))  
                    FinalD = 3'b001; 
                else 
                    FinalD = 3'b000; 
            S_RIGHT:
                if((currentX <= 8'd9) && ((currentY > 7'd60 && currentY < 7'd84) || (currentY > 7'd12 && currentY < 7'd36)))  
                    FinalD = 3'b000; 
                else if((currentX >= 8'd150) && ((currentY > 7'd84 && currentY < 7'd109) || (currentY > 7'd36 && currentY < 7'd60)))  
                    FinalD = 3'b000;
                else if((currentX >= 8'd125 && currentX <= 8'd134) && (currentY > 7'd0 && currentY < 7'd12))  
                    FinalD = 3'b000;
                else if(currentX < Width -  8'd9) 
                    FinalD = 3'b010; 
                else 
                    FinalD = 3'b000; 
            S_LEFT:
                if((currentX <= 8'd9) && ((currentY > 7'd60 && currentY < 7'd84) || (currentY > 7'd12 && currentY < 7'd36)))  
                    FinalD = 3'b000; 
                else if((currentX >= 8'd150) && ((currentY > 7'd84 && currentY < 7'd109) || (currentY > 7'd36 && currentY < 7'd60)))  
                    FinalD = 3'b000;
                else if((currentX >= 8'd125 && currentX <= 8'd134) && (currentY > 7'd0 && currentY < 7'd12))  
                    FinalD = 3'b000;
                else if(currentX > 8'd0) 
                    FinalD = 3'b011; 
                else 
                    FinalD = 3'b000; 
            S_SPACE_WAIT:
                FinalD = 3'b100; 
            S_DOWN:
                if((currentX <= 8'd9) && ((currentY >= 7'd60 && currentY < 7'd84) || (currentY >= 7'd12 && currentY < 7'd36)))  
                    FinalD = 3'b101; 
                else if((currentX >= 8'd150) && ((currentY >= 7'd84 && currentY < 7'd109) || (currentY >= 7'd36 && currentY < 7'd60)))  
                    FinalD = 3'b101;
                else if((currentX >= 8'd125 && currentX <= 8'd134) && (currentY >= 7'd0 && currentY < 7'd12))  
                    FinalD = 3'b101; 
                else 
                    FinalD = 3'b000;
            S_WAIT: 
                FinalD = 3'b000;   
            default: FinalD = 3'b000;            
        endcase
    end
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            currentState <= S_GetCommand; 
        else
            currentState <= nextState; 
    end
endmodule //ControlCommand

module ControlDraw(
    input[2:0] f_d,   
    input enableSignal,
    input Clk, 
    input ResetN, 
    output reg doNothing, sUp, sRight, sLeft, sDown, sSpace
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
      case(currentState) 
          START:
              doNothing = 1'b1; 
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
endmodule // ControlDraw


module DataPath (
    input doNothing, sUp, sRight, sLeft, sDown, sSpace,  
    input Clk, 
    input ResetN, 
    input[7:0] X, 
    input[6:0] Y,
    input[4:0] counter,
    output reg[7:0] FinalX,
    output reg[6:0] FinalY
); 
    always @(posedge Clk)
    begin
	     if(!ResetN) begin
		      FinalX <= 8'd0; 	// 0
		      FinalY <= 7'd109; 	// 109 
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
          if(counter > 5'd9) begin  
              FinalX <= X; 
              FinalY <= Y - 1'b1; 
          end 
          else if(counter <= 5'd9 && counter > 5'd0) begin 
              FinalX <= X; 
              FinalY <= Y + 1'b1; 
          end 
	     end
	     if(sDown) begin
		      FinalX <= X; 
		      FinalY <= Y + 1'b1; 
	     end
    end     
endmodule // DataPath