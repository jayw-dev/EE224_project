// Top module of the 4x4 systolic array.
// It consists of 16 Processing Elements (PEs)
// arranged in 4 rows and 4 columns.

module systolic_array(reset, clk, a_in, b_in, c_out);
input wire reset, clk;

input wire [31:0] a_in;
input wire [31:0] b_in;

// Each PE produces a 32-bit accumulated result. so 16*32 = 512
output wire [511:0] c_out;


// Internal wires used to transfer matrix A values horizontally.
// use buses to transfer matrix values horizontally(A) and vertically(B)

wire [7:0] a_bus [0:19];
wire [7:0] b_bus [0:19];
genvar i, j;

// INPUT CONNECTIONS FOR MATRIX A

// Connect the four input values of A to the first PE of each row.
// Each row receives one 8-bit value at a time.
generate
    for(i = 0; i < 4; i = i+1)
    begin : A_INPUT

        assign a_bus[i*5] = a_in[i*8 +: 8];

    end
endgenerate

// INPUT CONNECTIONS FOR MATRIX B

// Connect the four input values of B to the first PE of each column.
// Each column receives one 8-bit value at a time.
generate
    for(j = 0; j < 4; j = j+1)
    begin : B_INPUT

        assign b_bus[j] = b_in[j*8 +: 8];

    end
endgenerate



// INSTANTIATE OF 16 PROCESSING ELEMENTS

// Generate 4 rows and 4 columns of PEs.
// Each PE performs multiplication and accumulation
// while forwarding its input values to the neighbouring PEs.
generate
    for(i = 0; i < 4; i = i+1)
    begin : ROW

        for(j = 0; j < 4; j = j+1)
        begin : COL

            //instantiation
            PE PE_inst
            (
                .reset(reset),
                .clk(clk),

                // Receive A from the left side.
                .ain(a_bus[i*5+j]),

                // Receive B from the upper side.
                .bin(b_bus[i*4+j]),

                // Forward A to the PE on the right.
                .aout(a_bus[i*5+j+1]),

                // Forward B to the PE below.
                .bout(b_bus[(i+1)*4+j]),

                // Store the accumulated result of this PE
                .cout(c_out[(i*4+j)*32 +: 32])
            );

        end
    end
endgenerate

endmodule