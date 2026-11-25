`timescale 1ns/1ps

module tb_microcnn;

// Requantization shift values
localparam integer S1 = 9;
localparam integer S2 = 10;

// Systolic array signals
reg clk, reset;
reg [31:0] a_in, b_in;
wire [511:0] c_out;

systolic_array uut (
    .reset(reset),
    .clk(clk),
    .a_in(a_in),
    .b_in(b_in),
    .c_out(c_out)
);

always #5 clk = ~clk;


// Memories for weights, images and expected outputs
reg [7:0] B1_mem      [0:71];
reg [7:0] B2_mem      [0:1151];
reg [7:0] B3_mem      [0:3999];
reg [7:0] imgs_mem    [0:78399];
reg [7:0] labels_mem  [0:99];
reg [31:0] exp_logits [0:999];
reg [7:0] exp_pred    [0:99];

// Intermediate data storage
reg [7:0] img [0:783];
reg [7:0] A1 [0:6083];
reg signed [31:0] C1 [0:5407];
reg [7:0] a1 [0:1351];
reg [7:0] A2 [0:8711];
reg signed [31:0] C2 [0:1935];
reg [7:0] a2 [0:399];
reg signed [31:0] C3 [0:9];

// Temporary storage for 4x4 matrix multiplication tiles
reg [7:0] tileA [0:3][0:399];
reg [7:0] tileB [0:399][0:3];


// Feed one pair of matrix tiles into the systolic array
task run_4x4_tile;
    input integer K_len;
    integer t, idx, r, c;
    begin
        @(negedge clk);
        reset = 1;
        a_in  = 0;
        b_in  = 0;

        @(negedge clk);
        reset = 0;

        for (t = 0; t < K_len + 6; t = t + 1) begin

            @(negedge clk);

            for (r = 0; r < 4; r = r + 1) begin
                idx = t - r;

                if (idx >= 0 && idx < K_len)
                    a_in[r*8 +: 8] = tileA[r][idx];
                else
                    a_in[r*8 +: 8] = 8'd0;
            end

            for (c = 0; c < 4; c = c + 1) begin
                idx = t - c;

                if (idx >= 0 && idx < K_len)
                    b_in[c*8 +: 8] = tileB[idx][c];
                else
                    b_in[c*8 +: 8] = 8'd0;
            end
        end

        @(posedge clk);
        #1;

    end
endtask


// Matrix multiplication for the first convolution
task matmul_conv1;
    integer ti, tj, r, c, k;
    begin
        for (ti = 0; ti < 676; ti = ti + 4) begin
            for (tj = 0; tj < 8; tj = tj + 4) begin

                for (r = 0; r < 4; r = r + 1)
                    for (k = 0; k < 9; k = k + 1)
                        tileA[r][k] = (ti + r < 676) ? A1[(ti + r)*9 + k] : 8'd0;

                for (k = 0; k < 9; k = k + 1)
                    for (c = 0; c < 4; c = c + 1)
                        tileB[k][c] = (tj + c < 8) ? B1_mem[k*8 + (tj + c)] : 8'd0;

                run_4x4_tile(9);

                for (r = 0; r < 4; r = r + 1)
                    for (c = 0; c < 4; c = c + 1)
                        if ((ti + r < 676) && (tj + c < 8))
                            C1[(ti + r)*8 + (tj + c)] = c_out[(r*4 + c)*32 +: 32];

            end
        end
    end
endtask


// Matrix multiplication for the second convolution
task matmul_conv2;
    integer ti, tj, r, c, k;
    begin
        for (ti = 0; ti < 121; ti = ti + 4) begin
            for (tj = 0; tj < 16; tj = tj + 4) begin

                for (r = 0; r < 4; r = r + 1)
                    for (k = 0; k < 72; k = k + 1)
                        tileA[r][k] = (ti + r < 121) ? A2[(ti + r)*72 + k] : 8'd0;

                for (k = 0; k < 72; k = k + 1)
                    for (c = 0; c < 4; c = c + 1)
                        tileB[k][c] = (tj + c < 16) ? B2_mem[k*16 + (tj + c)] : 8'd0;

                run_4x4_tile(72);

                for (r = 0; r < 4; r = r + 1)
                    for (c = 0; c < 4; c = c + 1)
                        if ((ti + r < 121) && (tj + c < 16))
                            C2[(ti + r)*16 + (tj + c)] = c_out[(r*4 + c)*32 +: 32];

            end
        end
    end
endtask


// Matrix multiplication for the fully connected layer
task matmul_fc;
    integer tj, r, c, k;
    begin
        for (tj = 0; tj < 10; tj = tj + 4) begin

            for (r = 0; r < 4; r = r + 1)
                for (k = 0; k < 400; k = k + 1)
                    tileA[r][k] = (r == 0) ? a2[k] : 8'd0;

            for (k = 0; k < 400; k = k + 1)
                for (c = 0; c < 4; c = c + 1)
                    tileB[k][c] = (tj + c < 10) ? B3_mem[k*10 + (tj + c)] : 8'd0;

            run_4x4_tile(400);

            for (c = 0; c < 4; c = c + 1)
                if (tj + c < 10)
                    C3[tj + c] = c_out[c*32 +: 32];

        end
    end
endtask


// Variables used during image processing and verification
integer s, i, j, kh, kw, ch, dy, dx, p_idx;
reg signed [31:0] val, max_v, best_logit;
integer pred, correct, mismatch_count;


// Main simulation
initial begin
    clk = 0;
    reset = 1;
    a_in = 0;
    b_in = 0;

    // Load data exported from the Python model
    $readmemh("export/B1_conv1_9x8.hex",          B1_mem);
    $readmemh("export/B2_conv2_72x16.hex",        B2_mem);
    $readmemh("export/B3_fc_400x10.hex",          B3_mem);
    $readmemh("export/images_100x784.hex",       imgs_mem);
    $readmemh("export/labels_100.hex",            labels_mem);
    $readmemh("export/expected_logits_100x10.hex", exp_logits);
    $readmemh("export/expected_pred_100.hex",     exp_pred);

    correct = 0;
    mismatch_count = 0;

    // Process all 100 test images
    for (s = 0; s < 100; s = s + 1) begin

        for (i = 0; i < 784; i = i + 1)
            img[i] = imgs_mem[s*784 + i];

        // Convert the image into the first convolution's input matrix
        p_idx = 0;
        for (i = 0; i < 26; i = i + 1) begin
            for (j = 0; j < 26; j = j + 1) begin
                for (kh = 0; kh < 3; kh = kh + 1)
                    for (kw = 0; kw < 3; kw = kw + 1)
                        A1[p_idx*9 + kh*3 + kw] = img[(i + kh)*28 + (j + kw)];

                p_idx = p_idx + 1;
            end
        end

        matmul_conv1();

        // ReLU and max pooling after the first convolution
        for (i = 0; i < 13; i = i + 1) begin
            for (j = 0; j < 13; j = j + 1) begin
                for (ch = 0; ch < 8; ch = ch + 1) begin
                    max_v = 0;

                    for (dy = 0; dy < 2; dy = dy + 1) begin
                        for (dx = 0; dx < 2; dx = dx + 1) begin
                            val = C1[((i*2 + dy)*26 + (j*2 + dx))*8 + ch];

                            if (val > max_v) max_v = val;
                        end
                    end

                    max_v = max_v >>> S1;
                    if (max_v > 127) max_v = 127;
                    a1[(i*13 + j)*8 + ch] = max_v[7:0];

                end
            end
        end

        // Convert the first feature map into the second convolution's input matrix
        p_idx = 0;
        for (i = 0; i < 11; i = i + 1) begin
            for (j = 0; j < 11; j = j + 1) begin
                for (kh = 0; kh < 3; kh = kh + 1)
                    for (kw = 0; kw < 3; kw = kw + 1)
                        for (ch = 0; ch < 8; ch = ch + 1)
                            A2[p_idx*72 + (kh*3 + kw)*8 + ch] = a1[((i + kh)*13 + (j + kw))*8 + ch];

                p_idx = p_idx + 1;
            end
        end

        matmul_conv2();

        // ReLU and max pooling after the second convolution
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                for (ch = 0; ch < 16; ch = ch + 1) begin
                    max_v = 0;

                    for (dy = 0; dy < 2; dy = dy + 1) begin
                        for (dx = 0; dx < 2; dx = dx + 1) begin
                            val = C2[((i*2 + dy)*11 + (j*2 + dx))*16 + ch];

                            if (val > max_v) max_v = val;
                        end
                    end

                    max_v = max_v >>> S2;
                    if (max_v > 127) max_v = 127;
                    a2[(i*5 + j)*16 + ch] = max_v[7:0];

                end
            end
        end

        // Calculate the final 10 output values
        matmul_fc();

        // Compare output values and find the predicted class
        best_logit = C3[0];
        pred = 0;

        for (ch = 0; ch < 10; ch = ch + 1) begin
            if (C3[ch] !== exp_logits[s*10 + ch])
                mismatch_count = mismatch_count + 1;

            if (C3[ch] > best_logit) begin
                best_logit = C3[ch];
                pred = ch;
            end
        end

        if (pred == labels_mem[s]) begin
            correct = correct + 1;
            $display("sample %2d: PASS | prediction=%0d | label=%0d", s, pred, labels_mem[s]);
        end else begin
            $display("sample %2d: FAIL | prediction=%0d | label=%0d", s, pred, labels_mem[s]);
        end

    end

    // Print the final test results
    $display("------------------------------------------------");
    $display("micro-cnn systolic-array test");
    $display("accuracy: %0d/100", correct);
    $display("golden logit mismatches: %0d", mismatch_count);

    if (mismatch_count == 0)
        $display("RESULT: PASS (100%% bit-exact match with Python golden model)");
    else
        $display("RESULT: FAIL (check S1/S2 shifts or signed PE)");

    $stop;

end

endmodule