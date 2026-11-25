`timescale 1ns/1ps
module systolic_array_tb;
reg clk, reset;
reg [31:0] a_in, b_in;

// Combined output containing the results of all 16 PEs.
wire [511:0] c_out;


// Individual 32-bit outputs of all 16 PEs.
// done to show output in waveforms
wire [31:0] cout00, cout01, cout02, cout03;
wire [31:0] cout10, cout11, cout12, cout13;
wire [31:0] cout20, cout21, cout22, cout23;
wire [31:0] cout30, cout31, cout32, cout33;

reg [31:0] result [0:15];
reg [7:0] A [0:31];
reg [7:0] B [0:31];
reg [31:0] expected [0:15];


integer i, j, t;

systolic_array uut (
    .reset(reset),
    .clk(clk),
    .a_in(a_in),
    .b_in(b_in),
    .c_out(c_out)
);

// The clock changes its state every 5 ns.
always #5 clk = ~clk;

// Divide the combined output c_out into 16 separate 32-bit outputs.

assign cout00 = c_out[31:0];
assign cout01 = c_out[63:32];
assign cout02 = c_out[95:64];
assign cout03 = c_out[127:96];

assign cout10 = c_out[159:128];
assign cout11 = c_out[191:160];
assign cout12 = c_out[223:192];
assign cout13 = c_out[255:224];

assign cout20 = c_out[287:256];
assign cout21 = c_out[319:288];
assign cout22 = c_out[351:320];
assign cout23 = c_out[383:352];

assign cout30 = c_out[415:384];
assign cout31 = c_out[447:416];
assign cout32 = c_out[479:448];
assign cout33 = c_out[511:480];

initial
begin

    clk = 0;
    reset = 1;

    a_in = 0;
    b_in = 0;

	 // matrix A : 4*8
    A[0]=1;   A[1]=2;   A[2]=3;   A[3]=4;
    A[4]=1;   A[5]=0;   A[6]=2;   A[7]=1;

    A[8]=5;   A[9]=6;   A[10]=7;  A[11]=8;
    A[12]=2;  A[13]=1;  A[14]=0;  A[15]=2;

    A[16]=9;  A[17]=1;  A[18]=2;  A[19]=3;
    A[20]=0;  A[21]=3;  A[22]=1;  A[23]=1;

    A[24]=4;  A[25]=5;  A[26]=6;  A[27]=7;
    A[28]=1;  A[29]=2;  A[30]=2;  A[31]=0;

    // matrix B : 8*4 

    B[0]=1;   B[1]=0;   B[2]=2;   B[3]=1;
    B[4]=2;   B[5]=1;   B[6]=0;   B[7]=2;

    B[8]=0;   B[9]=3;   B[10]=1;  B[11]=1;
    B[12]=1;  B[13]=2;  B[14]=2;  B[15]=0;

    B[16]=1;  B[17]=1;  B[18]=0;  B[19]=1;
    B[20]=2;  B[21]=0;  B[22]=1;  B[23]=2;

    B[24]=0;  B[25]=1;  B[26]=2;  B[27]=1;
    B[28]=1;  B[29]=2;  B[30]=1;  B[31]=0;
	 
	 // correct values 

    expected[0]=11;  expected[1]=24;
    expected[2]=18;  expected[3]=11;

    expected[4]=31;  expected[5]=49;
    expected[6]=36;  expected[7]=28;

    expected[8]=21;  expected[9]=16;
    expected[10]=32; expected[11]=20;

    expected[12]=26; expected[13]=40;
    expected[14]=34; expected[15]=27;


    // Keep reset high initially to clear all PE registers.
    #12;
    reset = 0;

    for(t = 0; t < 14; t = t+1)
    begin
        // Change inputs at the negative edge of the clock.
        @(negedge clk);

        // Supply one element from each row of matrix A.
        // Each row starts one cycle after the previous row.
        for(i = 0; i < 4; i = i+1)
        begin
            if(t >= i && t < i+8)
                a_in[i*8 +: 8] = A[i*8 + (t-i)];
            else
                a_in[i*8 +: 8] = 0;
        end

        // Supply one element from each column of matrix B.
        // Each column starts one cycle after the previous column.
        for(j = 0; j < 4; j = j+1)
        begin
            if(t >= j && t < j+8)
                b_in[j*8 +: 8] = B[(t-j)*4 + j];
            else
                b_in[j*8 +: 8] = 0;
        end
    end

    repeat(2) @(posedge clk);
    #1;

    // STORE ALL 16 RESULTS
	 
    result[0]  = cout00;
    result[1]  = cout01;
    result[2]  = cout02;
    result[3]  = cout03;

    result[4]  = cout10;
    result[5]  = cout11;
    result[6]  = cout12;
    result[7]  = cout13;

    result[8]  = cout20;
    result[9]  = cout21;
    result[10] = cout22;
    result[11] = cout23;

    result[12] = cout30;
    result[13] = cout31;
    result[14] = cout32;
    result[15] = cout33;

    $display("\n========== INDIVIDUAL PE OUTPUTS ==========");

    for(i = 0; i < 16; i = i+1)
    begin
        $display("PE output %0d = %0d", i, result[i]);
    end


    // Display all 16 results in the form of a 4x4 matrix.

    $display("\n========== FINAL MATRIX ==========");

    for(i = 0; i < 4; i = i+1)
    begin

        for(j = 0; j < 4; j = j+1)
        begin
            $write("%0d\t", result[i*4+j]);
        end

        $display("");

    end
    // VERIFY RESULTS

    // Compare each PE output with its corresponding expected value.

    $display("\n========== VERIFICATION ==========");

    for(i = 0; i < 16; i = i+1)
    begin

        if(result[i] == expected[i])
            $display("PE %0d : PASS", i);

        else
            $display("PE %0d : FAIL | Got = %0d | Expected = %0d",
                i, result[i], expected[i]);

    end


    $display("\nSIMULATION COMPLETED!");

    // Wait for 10 ns and pause the simulation.
    #10;
    $stop;

end

endmodule