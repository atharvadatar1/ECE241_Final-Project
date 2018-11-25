// Created by Dhruv Patel
// Final Demo (Game Logic Module)

module FinalGameLogic(
    input ResetN,
    input Clk, 
    input[7:0] currentX, 
    input[6:0] currentY, 
    input[7:0] barrelX, 
    input[6:0] barrelY,
    output LED1, LED2, LED3, LED4, 
    output[6:0] HEX0,
    output[6:0] HEX1,  
    output gameOver
); 
    wire[8:0] newScore; 
    wire[8:0] cScore; 
    wire[2:0] newLives; 
    wire[2:0] cLives; 

    CurrentScore CS1(.ResetN(ResetN), .Clk(Clk), .Fscore(newScore), .ScoreOut(cScore)); 
    CurrentLives CL1(.ResetN(ResetN), .Clk(Clk), .FLives(newLives), .LivesOut(cLives)); 

    wire [25:0] Qout; 
    wire enable;
    EnableSignalGL ES1(.ResetN(ResetN), .Clk(Clk), .Q(Qout)); 
    assign enable = (Qout == 26'd0) ? 1'b1 : 1'b0; // Currently, the check speed is set to 2 Hz

    wire cS, cL; 
    GameLogicFSM GFSM1(.currentLives(cLives), .currentX(currentX), .currentY(currentY), .barrelX(barrelX), .barrelY(barrelY), 
                      .ResetN(ResetN), .Clk(Clk), .changeScore(cS), .changeLives(cL), .gameOver(gameOver), .enableSignal(enable));
    GameLogicDatapath GLD1(.changeLives(cL), .changeScore(cS), .currentScore(cScore), .currentLives(cLives), .ResetN(ResetN), .Clk(Clk), 
                           .FinalScore(newScore), .FinalLives(newLives), .cX(currentX), .cY(currentY)); 
    
    HEX H1(.B(cScore[3:0]), .S(HEX0)); 
    HEX H2(.B(cScore[7:4]), .S(HEX1)); 

    assign LED1 = cLives[0]; 
    assign LED2 = cLives[1]; 
    assign LED3 = cLives[2]; 

    assign LED4 = gameOver; 

endmodule // FinalGameLogic


module HEX(input [3:0]B, output [6:0]S); 
	wire [6:0]W; wire [3:0]D; 
	assign D = B; 
	assign W[0] = !((!D[0]|D[1]|D[2]|D[3]) & (D[0]|D[1]|!D[2]|D[3]) & (!D[0]|!D[1]|D[2]|!D[3]) & (!D[0]|D[1]|!D[2]|!D[3])); 
	assign W[1] = !((!D[0]|D[1]|!D[2]|D[3]) & (D[0]|!D[1]|!D[2]|D[3]) & (!D[0]|!D[1]|D[2]|!D[3]) & (D[0]|D[1]|!D[2]|!D[3]) & (D[0]|!D[1]|!D[2]|!D[3]) & (!D[0]|!D[1]|!D[2]|!D[3])); 
	assign W[2] = !((D[0]|!D[1]|D[2]|D[3]) & (D[0]|D[1]|!D[2]|!D[3]) & (D[0]|!D[1]|!D[2]|!D[3]) & (!D[0]|!D[1]|!D[2]|!D[3])); 
	assign W[3] = !((!D[0]|D[1]|D[2]|D[3]) & (D[0]|D[1]|!D[2]|D[3]) & (!D[0]|!D[1]|!D[2]|D[3]) & (D[0]|!D[1]|D[2]|!D[3]) & (!D[0]|!D[1]|!D[2]|!D[3])); 
	assign W[4] = !((!D[0]|D[1]|D[2]|D[3]) & (!D[0]|!D[1]|D[2]|D[3]) & (D[0]|D[1]|!D[2]|D[3]) & (!D[0]|D[1]|!D[2]|D[3]) & (!D[0]|!D[1]|!D[2]|D[3]) & (!D[0]|D[1]|D[2]|!D[3])); 
	assign W[5] = !((!D[0]|D[1]|D[2]|D[3]) & (D[0]|!D[1]|D[2]|D[3]) & (!D[0]|!D[1]|D[2]|D[3]) & (!D[0]|!D[1]|!D[2]|D[3])&(!D[0]|D[1]|!D[2]|!D[3])); 
	assign W[6] = !((D[0]|D[1]|D[2]|D[3]) & (!D[0]|D[1]|D[2]|D[3]) & (!D[0]|!D[1]|!D[2]|D[3]) & (D[0]|D[1]|!D[2]|!D[3])); 
	assign S = W; 
endmodule // hexDecoder 

module CurrentScore(
    input ResetN, 
    input Clk, 
    input[8:0] Fscore, 
    output reg[8:0] ScoreOut
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) begin
           ScoreOut <= 9'd0; 
        end
        else if(Fscore == 9'b111111111)
            ScoreOut <= 9'd0; 
        else begin
           ScoreOut <= Fscore; 
        end 
    end 
endmodule

module EnableSignalGL(
    input ResetN, 
    input Clk, 
    output reg[25:0] Q
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            Q <= 26'b01011111010111100000111111;
        else if(Q == 0) 
            Q <= 26'b01011111010111100000111111; // check speed is 2 Hz
        else 
            Q <= Q - 1'b1; 
    end
endmodule 

module CurrentLives(
    input ResetN, 
    input Clk, 
    input[2:0] FLives, 
    output reg[2:0] LivesOut
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) begin
           LivesOut <= 3'b111; 
        end
        else begin
           LivesOut <= FLives; 
        end 
    end 
endmodule

module GameLogicFSM(
    input[2:0] currentLives, 
    input[7:0] currentX, 
    input[6:0] currentY, 
    input[7:0] barrelX, 
    input[6:0] barrelY, 
    input ResetN, 
    input Clk, 
    input enableSignal, 
    output reg changeScore, changeLives, gameOver  
);
    reg[2:0] currentState; 
    reg[2:0] nextState;
    localparam S_CHECK = 3'b001, 
               S_CHECK_LIVES = 3'b010, 
               S_GAMEOVER = 3'b011,
               S_WAIT = 3'b100;  
    always @(*) 
    begin
        case(currentState)
            S_CHECK: if(barrelX <= currentX + 8'd9 && barrelX >= currentX && barrelY <= currentY + 7'd4 && barrelY >= currentY)
                        nextState = S_CHECK_LIVES; 
                     else
                        nextState = S_CHECK;  
            S_CHECK_LIVES: if(currentLives == 3'b001) 
                              nextState = S_GAMEOVER;
                           else
                              nextState = S_WAIT;
            S_WAIT: nextState = (enableSignal == 1'b1) ? S_CHECK : S_WAIT; 
            S_GAMEOVER: nextState = S_GAMEOVER;  
        endcase
    end
    always @(*)
    begin 
        changeScore = 1'b0; 
        changeLives = 1'b0; 
        gameOver = 1'b0; 
        case(currentState)
            S_CHECK:
                changeScore = 1'b1; 
            S_CHECK_LIVES:
                changeLives = 1'b1;
            S_GAMEOVER: 
                gameOver = 1'b1;
        endcase
    end 
    always @(posedge Clk) 
    begin
        if(!ResetN) 
            currentState <= S_CHECK; 
        else
            currentState <= nextState; 
    end
endmodule // GameLogic FSM

module GameLogicDatapath(
    input changeLives, changeScore, 
    input[8:0] currentScore, 
    input[2:0] currentLives, 
    input[7:0] cX, 
    input[6:0] cY,
    input ResetN, 
    input Clk, 
    output reg[8:0] FinalScore,
    output reg[2:0] FinalLives 
); 
    always @(posedge Clk) 
    begin
        if(!ResetN) begin
            FinalScore <= 9'd0; 
            FinalLives <= 3'b111; 
        end
        else if(changeScore) begin
            FinalScore <= cX + {1'b0 , cY};
            FinalLives <= currentLives; 
        end
        else if(changeLives) begin
            FinalScore <= currentScore; 
            if(currentLives == 3'b111) 
                FinalLives <= 3'b011; 
            else if(currentLives == 3'b011) 
                FinalLives <= 3'b001; 
            else
                FinalLives <=3'b000; 
        end
    end
endmodule // GameLogicDatapath