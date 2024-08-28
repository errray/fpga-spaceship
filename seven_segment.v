module seven_segment (
    input [8:0] number,
    output reg [6:0] hex0, hex1, hex2, hex3
);
    wire [4:0] digit0, digit1, digit2, digit3;
	 
	 assign digit0 = number % 10;
    assign digit1 = (number / 10) % 10;
    assign digit2 = (number / 100) % 10;
    assign digit3 = (number / 1000) % 10;

    always @(number) begin
       

        // Seven-segment display encoding
        case (digit0)
            4'd0: hex0 = 7'b1000000;
            4'd1: hex0 = 7'b1111001;
            4'd2: hex0 = 7'b0100100;
            4'd3: hex0 = 7'b0110000;
            4'd4: hex0 = 7'b0011001;
            4'd5: hex0 = 7'b0010010;
            4'd6: hex0 = 7'b0000010;
            4'd7: hex0 = 7'b1111000;
            4'd8: hex0 = 7'b0000000;
            4'd9: hex0 = 7'b0010000;
            default: hex0 = 7'b1111111;
        endcase

        case (digit1)
            4'd0: hex1 = 7'b1000000;
            4'd1: hex1 = 7'b1111001;
            4'd2: hex1 = 7'b0100100;
            4'd3: hex1 = 7'b0110000;
            4'd4: hex1 = 7'b0011001;
            4'd5: hex1 = 7'b0010010;
            4'd6: hex1 = 7'b0000010;
            4'd7: hex1 = 7'b1111000;
            4'd8: hex1 = 7'b0000000;
            4'd9: hex1 = 7'b0010000;
            default: hex1 = 7'b1111111;
        endcase

        case (digit2)
            4'd0: hex2 = 7'b1000000;
            4'd1: hex2 = 7'b1111001;
            4'd2: hex2 = 7'b0100100;
            4'd3: hex2 = 7'b0110000;
            4'd4: hex2 = 7'b0011001;
            4'd5: hex2 = 7'b0010010;
            4'd6: hex2 = 7'b0000010;
            4'd7: hex2 = 7'b1111000;
            4'd8: hex2 = 7'b0000000;
            4'd9: hex2 = 7'b0010000;
            default: hex2 = 7'b1111111;
        endcase

        case (digit3)
            4'd0: hex3 = 7'b1000000;
            4'd1: hex3 = 7'b1111001;
            4'd2: hex3 = 7'b0100100;
            4'd3: hex3 = 7'b0110000;
            4'd4: hex3 = 7'b0011001;
            4'd5: hex3 = 7'b0010010;
            4'd6: hex3 = 7'b0000010;
            4'd7: hex3 = 7'b1111000;
            4'd8: hex3 = 7'b0000000;
            4'd9: hex3 = 7'b0010000;
            default: hex3 = 7'b1111111;
        endcase
    end
endmodule

