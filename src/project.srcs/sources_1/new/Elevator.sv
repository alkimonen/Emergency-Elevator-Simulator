`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.12.2018 13:06:42
// Design Name: 
// Module Name: Elevator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Elevator(
	input clk, //100Mhz on Basys3    
    input execute,
    input resetTimer,
    input resetSystem,

	// FPGA pins for 8x8 display
	output reset_out, //shift register's reset
	output OE, 	//output enable, active low 
	output SH_CP,  //pulse to the shift register
	output ST_CP,  //pulse to store shift register
	output DS, 	//shift register's serial input data
	output [7:0] col_select, // active column, active high
    
	//7-segment signals
	output a, b, c, d, e, f, g, dp, 
    output [3:0] an,

	//matrix  4x4 keypad
	output [3:0] keyb_row,
	input  [3:0] keyb_col
	
    );
    
    // Directions of the elevator
    logic up = 0;
    logic down = 0;
    
    // State
    logic [3:0] state = 4'd14;
    
    logic [2:0] col_num;
    
    // Timing
    logic timer = 0;
    logic [28:0] counter = {29{1'b0}};
    logic [24:0] movement_counter = {25{1'b0}};
    
    // Number of passengers in elevator
    logic [3:0] carry = 4'd0;
    
    // Number of passsengers on each floor
    logic [3:0] f1 = 4'd0;
    logic [3:0] f2 = 4'd0;
    logic [3:0] f3 = 4'd0;
    
    //matrix keypad scanner
    logic [3:0] key_value;
    keypad4X4 keypad4X4_inst0(
	   .clk(clk),
	   .keyb_row(keyb_row), // just connect them to FPGA pins, row scanner
	   .keyb_col(keyb_col), // just connect them to FPGA pins, column scanner
        .key_value(key_value), //user's output code for detected pressed key: row[1:0]_col[1:0]
        .key_valid(key_valid)  // user's output valid: if the key is pressed long enough (more than 20~40 ms), key_valid becomes '1' for just one clock cycle.
    );
    
    //4 numbers to keep value of any of 4 digits
    //user's hex inputs for 4 digits
    logic [3:0] in0 = 4'd10; //initial value
    logic [3:0] in1 = 4'd0; //initial value
    logic [3:0] in2 = 4'd0; //initial value
    logic [3:0] in3 = 4'd0; //initial value

    SevSeg_4digit( clk, in3, in2, in1, in0, a, b, c, d, e, f, g, dp, an);
    
    always_ff @ ( posedge clk, posedge resetSystem )
    begin
        counter <= counter + 1;
        movement_counter <= movement_counter + 1;
        
        if ( resetTimer )
        begin
            in1 <= 4'd0;
            in2 <= 4'd0;
            in3 <= 4'd0;
        end
        else if ( ( counter == 29'd99_999_999 || counter == 29'd199_999_999
                    || counter == 29'd299_999_999 ) && timer )
            begin
            if ( in3 < 4'd9 )
                in3 <= in3 + 4'd1;
            else if ( in3 == 4'd9 )
                begin
                    in3 <= 4'd0;
                    if ( in2 < 4'd9 )
                        in2 <= in2 + 4'd1;
                    else if ( in2 == 4'd9 )
                    begin
                        in2 <= 4'd0;
                        in1 <= in1 + 4'd1;
                    end
                end
            end
        
        if ( counter == 29'd0 )
            in0 <= 4'd10;
        if ( movement_counter == 25'd24_999_999 )
        begin
            movement_counter <= {25{1'b0}};
            if ( up )
            begin
                if ( in0 == 4'd15 )
                    in0 <= 4'd10;
                else
                    in0 <= in0 + 1;
            end
            else if ( down )
            begin
                if ( in0 == 4'd10 )
                    in0 <= 4'd15;
                else
                    in0 <= in0 - 1;
            end
            else
                in0 <= 4'd10;
        end
        
        if ( resetSystem )
            begin
                up <= 0;
                down <= 0;
                state = 4'd14;
                f1 = 4'd0;
                f2 = 4'd0;
                f3 = 4'd0;
                timer <= 0;
                in0 <= 4'd10;
                in1 <= 4'd0;
                in2 <= 4'd0;
                in3 <= 4'd0;
            end
        else
            case ( state )
                4'd0: begin // f0
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 0;
                    end
                    else if ( counter == 29'd199_999_999)
                    begin
                        counter <= {29{1'b0}};
                        carry <= 4'd0;
                        state <= 4'd13;
                    end
                end
                4'd1: begin // f1
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 0;
                    end
                    else if ( counter == 29'd199_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        if ( f1 > 4'd3 ) begin
                            f1 <= f1 - 4'd4;
                            carry <= 4'd4;
                        end
                        else begin
                            carry <= carry + f1;
                            f1 <= 4'd0;
                        end
                        state <= 4'd6;
                    end
                end
                4'd2: begin // f2
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 0;
                    end
                    else if (  counter == 29'd199_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        if ( f2 > 4'd3 ) begin
                            f2 <= f2 - 4'd4;
                            carry <= 4'd4;
                            state <= 4'd9;
                        end
                        else if ( f1 > 4'd0 && carry + f2 + f1 < 4'd5 ) begin
                            carry <= carry + f2;
                            f2 <= 4'd0;
                            state <= 4'd8;
                        end
                        else begin
                            carry <= carry + f2;
                            f2 <= 4'd0;
                            state <= 4'd9;
                        end
                    end
                end
                4'd3: begin // f3
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 0;
                    end
                    else if ( counter == 29'd199_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        if ( f3 > 4'd3 ) begin
                            f3 <= f3 - 4'd4;
                            carry <= 4'd4;
                            state <= 4'd12;
                        end
                        else if ( f2 > 4'd0 && f3 + f2 < 4'd5 ) begin
                            carry <= f3;
                            f3 <= 4'd0;
                            state <= 4'd10;
                        end
                        else if ( f1 > 4'd0 && f3 + f1 < 4'd5 ) begin
                            carry <= f3;
                            f3 <= 4'd0;
                            state <= 4'd11;
                        end
                        else begin
                            carry <= f3;
                            f3 <= 4'd0;
                            state <= 4'd12;
                        end
                    end
                end
                4'd4: begin // f1u
                    if ( counter == 29'd0 )
                    begin
                        up <= 1;
                        down <= 0;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd2;
                    end
                end
                4'd5: begin // f1uu
                    if ( counter == 29'd0 )
                    begin
                        up <= 1;
                        down <= 0;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd7;
                    end
                end
                4'd6: begin // f1d
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin 
                        counter <= {29{1'b0}};
                        state <= 4'd0;
                    end
                end
                4'd7: begin // f2u
                    if ( counter == 29'd0 )
                    begin
                        up <= 1;
                        down <= 0;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin 
                        counter <= {29{1'b0}};
                        state <= 4'd3;
                    end
                end
                4'd8: begin // f2d
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd1;
                    end
                end
                4'd9: begin // f2dd
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd6;
                    end
                end
                4'd10: begin // f3d
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd2;
                    end
                end
                4'd11: begin // f3dd
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd8;
                    end
                end
                4'd12: begin // f3ddd
                    if ( counter == 29'd0 )
                    begin
                        up <= 0;
                        down <= 1;
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        state <= 4'd9;
                    end
                end
                4'd13: begin // f0u
                    if ( counter == 29'd0 )
                    begin
                        if ( f1 == 4'd0 && f2 == 4'd0 && f3 == 4'd0 )
                        begin
                            state <= 4'd14;
                            timer <= 0;
                            up <= 0;
                            down <= 0;
                        end
                        else
                        begin
                            up <= 1;
                            down <= 0;
                        end
                    end
                    else if ( counter == 29'd299_999_999 )
                    begin
                        counter <= {29{1'b0}};
                        if ( f3 > 4'd3 )
                            state <= 4'd5;
                        else if ( f2 > 4'd3 )
                            state <= 4'd4;
                        else if ( f1 > 4'd3 )
                            state <= 4'd1;
                        else if ( f3 > 4'd0 )
                            state <= 4'd5;
                        else if ( f2 > 4'd0 )
                            state <= 4'd4;
                        else if ( f1 > 4'd0 )
                            state <= 4'd1;
                        else
                        begin
                            state <= 4'd14;
                            timer <= 0;
                            up <= 0;
                            down <= 0;
                        end
                    end
                end
                4'd14: begin // stop
                    if ( execute )
                    begin
                        state <= 4'd13;
                        counter <= {29{1'b0}};
                        movement_counter <= movement_counter + 1;
                        timer <= 1;
                        in0 <= 4'd10;
                        in1 <= 4'd0;
                        in2 <= 4'd0;
                        in3 <= 4'd0;
                    end
                    if ( key_valid == 1'b1 )
                    begin
                        case( key_value ) 
                            4'b01_00:  //increments number of passengers at floor 1.
                                if ( f1 < 4'd12 )
                                    f1 <= f1 + 4'd1;
                            4'b01_01:  //decrements number of passengers at floor 1.
                                if ( f1 > 4'd0 )
                                    f1 <= f1 - 4'd1;
                            4'b10_00:  //increments number of passengers at floor 2.
                                if ( f2 < 4'd12 )
                                    f2 <= f2 + 4'd1;
                            4'b10_01:  //decrements number of passengers at floor 2.
                                if ( f2 > 4'd0 )
                                    f2 <= f2 - 4'd1;
                            4'b11_00:  //increments number of passengers at floor 3.
                                if ( f3 < 4'd12 )
                                    f3 <= f3 + 4'd1;
                            4'b11_01:  //decrements number of passengers at floor 3.
                                if ( f3 > 4'd0 )
                                    f3 <= f3 - 4'd1;
                        endcase
                    end
                end
            endcase
    end
    
    
    logic [0:7] [7:0] image_red = 
{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
    logic [0:7] [7:0]  image_green = 
{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
    logic [0:7] [7:0]  image_blue = 
{8'b00000011, 8'b00000011, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};

    // This module displays 8x8 image on LED display module. 
    display_8x8 display_8x8_0(
    	.clk(clk),
	
    	// RGB data for display current column
    	.red_vect_in(image_red[col_num]),
    	.green_vect_in(image_green[col_num]),
    	.blue_vect_in(image_blue[col_num]),
	
    	.col_data_capture(), // unused
    	.col_num(col_num),
	
    	// FPGA pins for display
    	.reset_out(reset_out),
    	.OE(OE),
    	.SH_CP(SH_CP),
    	.ST_CP(ST_CP),
    	.DS(DS),
    	.col_select(col_select)   
    );
    
    always@ (posedge clk)
    begin
        
    	case ( f1 )
        4'd0 : begin
    	   image_red[2][2] = 0; image_red[2][3] = 0; image_red[3][2] = 0; image_red[3][3] = 0;
    	   image_red[4][2] = 0; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd1 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 0; image_red[3][2] = 0; image_red[3][3] = 0;
    	   image_red[4][2] = 0; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd2 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 0; image_red[3][3] = 0;
    	   image_red[4][2] = 0; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd3 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 0;
    	   image_red[4][2] = 0; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd4 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 0; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd5 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 0; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd6 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 0; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd7 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 0;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd8 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 1;
    	   image_red[6][2] = 0; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd9 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 1;
    	   image_red[6][2] = 1; image_red[6][3] = 0; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd10 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 1;
    	   image_red[6][2] = 1; image_red[6][3] = 1; image_red[7][2] = 0; image_red[7][3] = 0;
    	   end
    	4'd11 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 1;
    	   image_red[6][2] = 1; image_red[6][3] = 1; image_red[7][2] = 1; image_red[7][3] = 0;
    	   end
    	4'd12 : begin
    	   image_red[2][2] = 1; image_red[2][3] = 1; image_red[3][2] = 1; image_red[3][3] = 1;
    	   image_red[4][2] = 1; image_red[4][3] = 1; image_red[5][2] = 1; image_red[5][3] = 1;
    	   image_red[6][2] = 1; image_red[6][3] = 1; image_red[7][2] = 1; image_red[7][3] = 1;
    	   end
    	endcase
    	
    	case ( f2 )
        4'd0 : begin
    	   image_red[2][4] = 0; image_red[2][5] = 0; image_red[3][4] = 0; image_red[3][5] = 0;
    	   image_red[4][4] = 0; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd1 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 0; image_red[3][4] = 0; image_red[3][5] = 0;
    	   image_red[4][4] = 0; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd2 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 0; image_red[3][5] = 0;
    	   image_red[4][4] = 0; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd3 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 0;
    	   image_red[4][4] = 0; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd4 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 0; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd5 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 0; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd6 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 0; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd7 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 0;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd8 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 1;
    	   image_red[6][4] = 0; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd9 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 1;
    	   image_red[6][4] = 1; image_red[6][5] = 0; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd10 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 1;
    	   image_red[6][4] = 1; image_red[6][5] = 1; image_red[7][4] = 0; image_red[7][5] = 0;
    	   end
    	4'd11 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 1;
    	   image_red[6][4] = 1; image_red[6][5] = 1; image_red[7][4] = 1; image_red[7][5] = 0;
    	   end
    	4'd12 : begin
    	   image_red[2][4] = 1; image_red[2][5] = 1; image_red[3][4] = 1; image_red[3][5] = 1;
    	   image_red[4][4] = 1; image_red[4][5] = 1; image_red[5][4] = 1; image_red[5][5] = 1;
    	   image_red[6][4] = 1; image_red[6][5] = 1; image_red[7][4] = 1; image_red[7][5] = 1;
    	   end
    	endcase
    	
    	case ( f3 )
        4'd0 : begin
    	   image_red[2][6] = 0; image_red[2][7] = 0; image_red[3][6] = 0; image_red[3][7] = 0;
    	   image_red[4][6] = 0; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd1 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 0; image_red[3][6] = 0; image_red[3][7] = 0;
    	   image_red[4][6] = 0; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd2 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 0; image_red[3][7] = 0;
    	   image_red[4][6] = 0; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd3 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 0;
    	   image_red[4][6] = 0; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd4 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 0; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd5 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 0; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd6 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 0; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd7 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 0;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd8 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 1;
    	   image_red[6][6] = 0; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd9 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 1;
    	   image_red[6][6] = 1; image_red[6][7] = 0; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd10 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 1;
    	   image_red[6][6] = 1; image_red[6][7] = 1; image_red[7][6] = 0; image_red[7][7] = 0;
    	   end
    	4'd11 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 1;
    	   image_red[6][6] = 1; image_red[6][7] = 1; image_red[7][6] = 1; image_red[7][7] = 0;
    	   end
    	4'd12 : begin
    	   image_red[2][6] = 1; image_red[2][7] = 1; image_red[3][6] = 1; image_red[3][7] = 1;
    	   image_red[4][6] = 1; image_red[4][7] = 1; image_red[5][6] = 1; image_red[5][7] = 1;
    	   image_red[6][6] = 1; image_red[6][7] = 1; image_red[7][6] = 1; image_red[7][7] = 1;
    	   end
    	endcase
    	
    	
    	case ( state )
    	   4'd0 : begin
    	       image_red[0][0] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][0] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][1] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][1] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][0] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][0] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][1] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][1] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][3:2] = 2'b00;
    	       image_red[1][3:2] = 2'b00;
    	       image_blue[0][3:2] = 2'b00;
    	       image_blue[1][3:2] = 2'b00;
    	       end
    	   4'd1 : begin
    	       image_red[0][2] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][2] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][3] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][3] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][2] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][2] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][3] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][3] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][1:0] = 2'b00;
    	       image_red[1][1:0] = 2'b00;
    	       image_blue[0][1:0] = 2'b00;
    	       image_blue[1][1:0] = 2'b00;
    	       image_red[0][5:4] = 2'b00;
    	       image_red[1][5:4] = 2'b00;
    	       image_blue[0][5:4] = 2'b00;
    	       image_blue[1][5:4] = 2'b00;
    	       end
    	   4'd2 : begin
    	       image_red[0][4] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][4] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][5] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][5] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][4] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][4] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][5] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][5] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][3:2] = 2'b00;
    	       image_red[1][3:2] = 2'b00;
    	       image_blue[0][3:2] = 2'b00;
    	       image_blue[1][3:2] = 2'b00;
    	       image_red[0][7:6] = 2'b00;
    	       image_red[1][7:6] = 2'b00;
    	       image_blue[0][7:6] = 2'b00;
    	       image_blue[1][7:6] = 2'b00;
    	       end
    	   4'd3 : begin
    	       image_red[0][6] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][6] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][7] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][7] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][6] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][6] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][7] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][7] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][5:4] = 2'b00;
    	       image_red[1][5:4] = 2'b00;
    	       image_blue[0][5:4] = 2'b00;
    	       image_blue[1][5:4] = 2'b00;
    	       end
    	   4'd4 : begin
    	       image_red[0][2] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][2] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][3] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][3] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][2] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][2] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][3] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][3] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][1:0] = 2'b00;
    	       image_red[1][1:0] = 2'b00;
    	       image_blue[0][1:0] = 2'b00;
    	       image_blue[1][1:0] = 2'b00;
    	       end
    	   4'd5 : begin
    	       image_red[0][2] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][2] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][3] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][3] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][2] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][2] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][3] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][3] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][1:0] = 2'b00;
    	       image_red[1][1:0] = 2'b00;
    	       image_blue[0][1:0] = 2'b00;
    	       image_blue[1][1:0] = 2'b00;
    	       end
    	   4'd6 : begin
    	       image_red[0][2] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][2] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][3] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][3] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][2] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][2] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][3] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][3] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][5:4] = 2'b00;
    	       image_red[1][5:4] = 2'b00;
    	       image_blue[0][5:4] = 2'b00;
    	       image_blue[1][5:4] = 2'b00;
    	       end
    	   4'd7 : begin
    	       image_red[0][4] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][4] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][5] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][5] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][4] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][4] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][5] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][5] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][3:2] = 2'b00;
    	       image_red[1][3:2] = 2'b00;
    	       image_blue[0][3:2] = 2'b00;
    	       image_blue[1][3:2] = 2'b00;
    	       end
    	   4'd8 : begin
    	       image_red[0][4] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][4] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][5] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][5] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][4] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][4] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][5] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][5] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][7:6] = 2'b00;
    	       image_red[1][7:6] = 2'b00;
    	       image_blue[0][7:6] = 2'b00;
    	       image_blue[1][7:6] = 2'b00;
    	       end
    	   4'd9 : begin
    	       image_red[0][4] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][4] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][5] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][5] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][4] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][4] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][5] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][5] = (carry > 4'd1)? 0 : 1;
    	       image_red[0][7:6] = 2'b00;
    	       image_red[1][7:6] = 2'b00;
    	       image_blue[0][7:6] = 2'b00;
    	       image_blue[1][7:6] = 2'b00;
    	       end
    	   4'd10 : begin
    	       image_red[0][6] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][6] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][7] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][7] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][6] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][6] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][7] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][7] = (carry > 4'd1)? 0 : 1;
    	       end
    	   4'd11 : begin
    	       image_red[0][6] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][6] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][7] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][7] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][6] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][6] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][7] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][7] = (carry > 4'd1)? 0 : 1;
    	       end
    	   4'd12 : begin
    	       image_red[0][6] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][6] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][7] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][7] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][6] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][6] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][7] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][7] = (carry > 4'd1)? 0 : 1;
    	       end
    	   4'd13 : begin
    	       image_red[0][0] = (carry > 4'd2)? 1 : 0;
    	       image_blue[0][0] = (carry > 4'd2)? 0 : 1;
    	       image_red[0][1] = (carry > 4'd0)? 1 : 0;
    	       image_blue[0][1] = (carry > 4'd0)? 0 : 1;
    	       image_red[1][0] = (carry > 4'd3)? 1 : 0;
    	       image_blue[1][0] = (carry > 4'd3)? 0 : 1;
    	       image_red[1][1] = (carry > 4'd1)? 1 : 0;
    	       image_blue[1][1] = (carry > 4'd1)? 0 : 1;
    	       end
    	   4'd14 : begin
    	       image_blue[0][7:0] = 2'b00000011;
    	       image_blue[1][7:0] = 2'b00000011;
    	       image_red[0][7:0] = 2'b00000000;
    	       image_red[1][7:0] = 2'b00000000;
    	       end
        endcase
    end
    
endmodule