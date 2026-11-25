module PE(reset, clk, ain, bin, aout, bout, cout);

parameter W = 8;

input wire reset, clk;
input wire signed [W-1:0] ain, bin;

output reg signed [W-1:0] aout, bout;
output reg signed [4*W-1:0] cout;


always @(posedge clk or posedge reset)
begin

    // asynchronous reset (active high)
    if(reset)
    begin
        aout <= 0;
        bout <= 0;
        cout <= 0;
    end

    else
    begin
// Forward input A to the next PE 
        aout <= ain;

// Forward input B to the next PE 
        bout <= bin;

//Multiply the incoming A and B values and add
//the product to the previously accumulated result
        cout <= cout + ain*bin;
    end

end

endmodule