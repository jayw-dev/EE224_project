`timescale 1ns/1ps

// Testbench module for testing the Processing Element (PE).
module PE_tb;

    reg clk, reset;
    reg [7:0] ain, bin;

    wire [7:0] aout, bout;
    wire [31:0] cout;


   // instantiation
    PE uut (
        .reset(reset),
        .clk(clk),
        .ain(ain),
        .bin(bin),
        .aout(aout),
        .bout(bout),
        .cout(cout)
    );

    // Generate a clock with a time period of 10 ns.
    // The clock changes its state every 5 ns.
    always #5 clk = ~clk;

    initial
    begin
        // Initialize clock and reset.
        clk = 0;
        reset = 1;

        // Initially set both inputs to zero.
        ain = 0;
        bin = 0;

        // Keep reset active for 12 ns and then release it.
        #12;
        reset = 0;


        // Test 1: Apply inputs 2 and 3.
        @(negedge clk);
        ain = 2;
        bin = 3;

        // Test 2: Apply inputs 4 and 5.
        @(negedge clk);
        ain = 4;
        bin = 5;

        // Test 3: Apply inputs 3 and 2.
        @(negedge clk);
        ain = 3;
        bin = 2;

        // Test 4: Apply inputs 6 and 4.
        @(negedge clk);
        ain = 6;
        bin = 4;

        // Test 5: Apply inputs 1 and 7.
        @(negedge clk);
        ain = 1;
        bin = 7;


        // Stop supplying non-zero inputs to the PE.
        @(negedge clk);
        ain = 0;
        bin = 0;


        // Wait for the outputs to settle before displaying them.
        #2;

        // Display the final forwarded inputs and accumulated result.
        $display("--------------------------------");
        $display("Final aout = %0d", aout);
        $display("Final bout = %0d", bout);
        $display("Final cout = %0d", cout);
        $display("--------------------------------");


        
        // Expected result = (2*3) + (4*5) + (3*2) + (6*4) + (1*7)
        //                  = 6 + 20 + 6 + 24 + 7 = 63.
        if(cout == 63)
            $display("TEST PASSED!");
        else
            $display("TEST FAILED!");


        // Wait for 10 ns before pausing the simulation.
        #10;

        $stop;  
    end


    // Continuously display the input and output values whenever
    // any of the monitored signals changes.
    // %0d is used to display the values in decimal format.
    initial
    begin
        $monitor("Time=%0t | ain=%0d bin=%0d | aout=%0d bout=%0d | cout=%0d",
                  $time, ain, bin, aout, bout, cout);
    end

endmodule