`timescale 1ns/1ps

module tb_line_buffer_3x3;

    // --------------------------------------------------------
    // ????
    // --------------------------------------------------------
    localparam DATA_WIDTH = 8;
    localparam WIDTH      = 5;
    localparam HEIGHT     = 5;
    localparam FRAME_GAP  = 20;  // ??????

    reg clk;
    reg rst_n;

    reg                  in_valid;
    reg  [DATA_WIDTH-1:0] pix_in;

    wire win_valid;
    wire [DATA_WIDTH-1:0] p00, p01, p02;
    wire [DATA_WIDTH-1:0] p10, p11, p12;
    wire [DATA_WIDTH-1:0] p20, p21, p22;

    // --------------------------------------------------------
    // DUT ??
    // --------------------------------------------------------
    line_buffer_3x3 #(
        .DATA_WIDTH(DATA_WIDTH),
        .WIDTH     (WIDTH),
        .HEIGHT    (HEIGHT)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .pix_in   (pix_in),

        .win_valid(win_valid),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    // --------------------------------------------------------
    // ??
    // --------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100MHz
    end

    // --------------------------------------------------------
    // ??
    // --------------------------------------------------------
    initial begin
        rst_n   = 0;
        in_valid = 0;
        pix_in   = 0;
        #100;
        rst_n = 1;
    end

    // --------------------------------------------------------
    // ???????
    //  - ?? WIDTH ????in_valid ?? WIDTH ????? 1
    //  - ?????? in_valid????????
    // --------------------------------------------------------
    task send_line(input integer row_idx, input integer frame_base);
        integer col;
        integer pixel;
    begin
        // ?????? WIDTH ????in_valid=1??????
        for (col = 0; col < WIDTH; col = col + 1) begin
            pixel = frame_base + row_idx*WIDTH + col + 1;  // ???
            @(posedge clk);
            in_valid <= 1'b1;
            pix_in   <= pixel[7:0];

            $display("???? frame=%0d row=%0d col=%0d val=%0d  time=%0t",
                     frame_base/100, row_idx, col, pixel, $time);
        end

        // ????in_valid ?????????
        @(posedge clk);
        in_valid <= 1'b0;
        pix_in   <= 0;

        // ?????3 ???
        repeat(3) @(posedge clk);
    end
    endtask

    // --------------------------------------------------------
    // ??????
    // --------------------------------------------------------
    task send_frame(input integer frame_idx);
        integer row;
        integer frame_base;
    begin
        frame_base = frame_idx * 100;  // ??????
        
        $display("????? %0d ????????=%0d", frame_idx, frame_base);
        
        for (row = 0; row < HEIGHT; row = row + 1) begin
            send_line(row, frame_base);
        end
        
        $display("? %0d ???????", frame_idx);
    end
    endtask

    // --------------------------------------------------------
    // ?????
    // --------------------------------------------------------
    task insert_frame_gap(input integer gap_cycles);
        integer i;
    begin
        $display("?????????=%0d", gap_cycles);
        in_valid <= 1'b0;
        pix_in   <= 0;
        
        for (i = 0; i < gap_cycles; i = i + 1) begin
            @(posedge clk);
        end
    end
    endtask

    // --------------------------------------------------------
    // ?????
    // --------------------------------------------------------
    integer frame;
    integer total_frames = 3;

    initial begin
        @(posedge rst_n);
        #20;

        $display("????????? %0d ???????? %0d ???", total_frames, FRAME_GAP);
        $display("?????%0dx%0d", WIDTH, HEIGHT);
        $display("==============================================================");

        for (frame = 0; frame < total_frames; frame = frame + 1) begin
            // ????
            send_frame(frame);
            
            // ??????????????
            if (frame < total_frames - 1) begin
                insert_frame_gap(FRAME_GAP);
            end
        end

        $display("==============================================================");
        $display("?? %0d ???????", total_frames);
        
        // ???????????????????????
        repeat(50) @(posedge clk);

        $display("????");
        $stop;
    end

    // --------------------------------------------------------
    // ?? window ??
    // --------------------------------------------------------
    integer window_count = 0;
    
    always @(posedge clk) begin
        if (win_valid) begin
            window_count = window_count + 1;
            $display("??[%0d] @ %0t", window_count, $time);
            $display("  %0d  %0d  %0d", p00, p01, p02);
            $display("  %0d  %0d  %0d", p10, p11, p12);
            $display("  %0d  %0d  %0d", p20, p21, p22);
            
            // ???????????????
            if (window_count == 1) begin
                $display("???????");
            end
        end
    end

    // --------------------------------------------------------
    // ??????
    // --------------------------------------------------------
    // ??????????????????
   

endmodule
