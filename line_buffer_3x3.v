`timescale 1ns / 1ps

module line_buffer_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter WIDTH      = 640,   // 一行像素数 (<=1024)
    parameter HEIGHT     = 480    // 图像高度（真实行数）
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   in_valid,     // 输入像素有效
    input  wire [DATA_WIDTH-1:0]  pix_in,       // 单通道像素输入

    // 输出到 window_3x3 的 3x3 窗口
    output wire                   win_valid,
    output wire [DATA_WIDTH-1:0]  p00, p01, p02,
    output wire [DATA_WIDTH-1:0]  p10, p11, p12,
    output wire [DATA_WIDTH-1:0]  p20, p21, p22
);

    // ======================================================
    // 1) 行/列计数：跟随 in_valid 递增（真实输入的行列）
    // ======================================================
    reg [9:0]   x_cnt;   // 列计数
    reg [15:0]  y_cnt;   // 行计数 (0..HEIGHT-1)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 10'd0;
            y_cnt <= 16'd0;
        end else if (in_valid) begin
            if (x_cnt == WIDTH-1) begin
                x_cnt <= 10'd0;
                if (y_cnt < HEIGHT-1)
                    y_cnt <= y_cnt + 1'b1;
            end else begin
                x_cnt <= x_cnt + 1'b1;
            end
        end
    end

    // ======================================================
    // 2) 两级流水：打两拍给 window
    //    ——pix_curr_s1_stream / y_cnt_d2 / x_cnt_d2 / in_v_d2
    // ======================================================
    reg                  in_v_d1, in_v_d2;
    reg [9:0]            x_cnt_d1, x_cnt_d2;
    reg [15:0]           y_cnt_d1, y_cnt_d2;
    reg [DATA_WIDTH-1:0] pix_d1;
    reg [DATA_WIDTH-1:0] pix_curr_s1_stream;   // “正常模式”下给 window 的当前行像素

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_v_d1            <= 1'b0;
            in_v_d2            <= 1'b0;
            x_cnt_d1           <= 10'd0;
            x_cnt_d2           <= 10'd0;
            y_cnt_d1           <= 16'd0;
            y_cnt_d2           <= 16'd0;
            pix_d1             <= {DATA_WIDTH{1'b0}};
            pix_curr_s1_stream <= {DATA_WIDTH{1'b0}};
        end else begin
            // 第一级
            in_v_d1 <= in_valid;
            if (in_valid) begin
                x_cnt_d1 <= x_cnt;
                y_cnt_d1 <= y_cnt;
                pix_d1   <= pix_in;
            end

            // 第二级
            in_v_d2 <= in_v_d1;
            if (in_v_d1) begin
                x_cnt_d2           <= x_cnt_d1;
                y_cnt_d2           <= y_cnt_d1;
                pix_curr_s1_stream <= pix_d1;
            end
        end
    end

    // ======================================================
    // 3) 底部 padding 控制：在最后一行有效数据结束后空 BOTTOM_GAP 拍，再输出一行
    // ======================================================
    localparam BOTTOM_GAP = 5;

    reg        padding_mode;      // 1：正在输出底 padding 行
    reg [2:0]  gap_cnt;           // 空白计数
    reg [9:0]  bottom_x_cnt;      // 底行扫描列 (0..WIDTH)
    reg        frame_done_pulse;  // 一帧结束脉冲（用于清空 RAM）

    wire last_pixel_2nd_stage;
    assign last_pixel_2nd_stage =
        in_v_d2 &&
        (y_cnt_d2 == (HEIGHT-1)) &&
        (x_cnt_d2 == (WIDTH-1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            padding_mode     <= 1'b0;
            gap_cnt          <= 3'd0;
            bottom_x_cnt     <= 10'd0;
            frame_done_pulse <= 1'b0;
        end else begin
            frame_done_pulse <= 1'b0;   // 默认拉低

            if (!padding_mode) begin
                // 正常模式：等待最后一个像素进入第二级
                if (last_pixel_2nd_stage) begin
                    gap_cnt <= 3'd1;
                end else if (gap_cnt != 3'd0 && gap_cnt < BOTTOM_GAP) begin
                    gap_cnt <= gap_cnt + 1'b1;
                end else if (gap_cnt == BOTTOM_GAP) begin
                    // GAP 结束，进入 padding 行
                    padding_mode <= 1'b1;
                    bottom_x_cnt <= 10'd0;
                    gap_cnt      <= 3'd0;
                end
            end else begin
                // padding_mode: bottom_x_cnt 从 0 数到 WIDTH
                if (bottom_x_cnt == WIDTH) begin
                    // 这一拍，是最后一个像素的 q 在流水后输出的时刻
                    padding_mode     <= 1'b0;
                    bottom_x_cnt     <= 10'd0;
                    frame_done_pulse <= 1'b1;   // ★ 一帧结束：清 RAM
                end else begin
                    bottom_x_cnt <= bottom_x_cnt + 1'b1;
                end
            end
        end
    end

    // 给 RAM 的读地址 & 读使能
    wire [9:0] addr_x_for_ram = padding_mode ? bottom_x_cnt : x_cnt;
    wire       rden_for_ram   = padding_mode ? (bottom_x_cnt < WIDTH) : in_valid;

    // ======================================================
    // 4) 两个行 RAM：带 aclr 的 register IP
    // ======================================================
    wire [9:0] ram0_rdaddr = addr_x_for_ram;
    wire [9:0] ram1_rdaddr = addr_x_for_ram;
    wire       ram0_rden   = rden_for_ram;
    wire       ram1_rden   = rden_for_ram;

    reg  [DATA_WIDTH-1:0] ram0_data;
    reg  [9:0]            ram0_wraddr;
    reg                   ram0_wren;
    wire [DATA_WIDTH-1:0] ram0_q;

    reg  [DATA_WIDTH-1:0] ram1_data;
    reg  [9:0]            ram1_wraddr;
    reg                   ram1_wren;
    wire [DATA_WIDTH-1:0] ram1_q;

    // 你的 IP：
    // register(aclr, clock, data, rdaddress, wraddress, wren, rden, q);
    register u_ram0 (
        .aclr     (frame_done_pulse),  // ★ 一帧结束时异步清零
        .clock    (clk),
        .data     (ram0_data),
        .rdaddress(ram0_rdaddr),
        .wraddress(ram0_wraddr),
        .wren     (ram0_wren),
        .rden     (ram0_rden),
        .q        (ram0_q)
    );

    register u_ram1 (
        .aclr     (frame_done_pulse),  // ★ 一帧结束时异步清零
        .clock    (clk),
        .data     (ram1_data),
        .rdaddress(ram1_rdaddr),
        .wraddress(ram1_wraddr),
        .wren     (ram1_wren),
        .rden     (ram1_rden),
        .q        (ram1_q)
    );

    // ======================================================
    // 5) 垂直 3 像素 & 写入乒乓
    // ======================================================
    // padding 行使用虚拟行号 HEIGHT，其实只影响 m1/m2 的选择
    wire [15:0] y_for_window = padding_mode ? HEIGHT[15:0] : y_cnt_d2;

    // 真正送给 window 的 curr
    wire [DATA_WIDTH-1:0] pix_curr_s1 =
        padding_mode           ? {DATA_WIDTH{1'b0}} :   // 底行 curr = 0
        (in_v_d2              ) ? pix_curr_s1_stream :
                                  {DATA_WIDTH{1'b0}};

    // m1/m2 正常情况
    wire [DATA_WIDTH-1:0] pix_m1_normal;
    wire [DATA_WIDTH-1:0] pix_m2_normal;

    assign pix_m1_normal =
        (y_for_window == 16'd0) ? {DATA_WIDTH{1'b0}} :           // 顶行无上一行
        (y_for_window == 16'd1) ? ram0_q :                       // 第1行的上一行在 RAM0
        ( ((y_for_window - 1) & 16'h0001) ? ram1_q : ram0_q );   // y-1奇 -> RAM1, 偶 -> RAM0

    assign pix_m2_normal =
        (y_for_window <= 16'd1) ? {DATA_WIDTH{1'b0}} :           // 前两行无 y-2
        ( ((y_for_window - 2) & 16'h0001) ? ram1_q : ram0_q );   // y-2 奇偶判断

    // m1/m2 padding 行：m1 用最后一行，m2 用倒数第二行（不颠倒）
    localparam [15:0] LAST_ROW = HEIGHT-1;

    wire last_row_is_odd  = LAST_ROW[0];   // 1: 最后一行行号为奇数
    wire [DATA_WIDTH-1:0] pix_m1_bottom =
        last_row_is_odd ? ram1_q : ram0_q; // m1 = 最后一行
    wire [DATA_WIDTH-1:0] pix_m2_bottom =
        last_row_is_odd ? ram0_q : ram1_q; // m2 = 倒数第二行（取反）

    wire [DATA_WIDTH-1:0] pix_m1_s1 = padding_mode ? pix_m1_bottom : pix_m1_normal;
    wire [DATA_WIDTH-1:0] pix_m2_s1 = padding_mode ? pix_m2_bottom : pix_m2_normal;

    // 写当前行进 RAM（乒乓）——只在正常模式，padding 模式不写
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram0_wraddr <= 10'd0;
            ram1_wraddr <= 10'd0;
            ram0_wren   <= 1'b0;
            ram1_wren   <= 1'b0;
            ram0_data   <= {DATA_WIDTH{1'b0}};
            ram1_data   <= {DATA_WIDTH{1'b0}};
        end else begin
            ram0_wren <= 1'b0;
            ram1_wren <= 1'b0;

            if (!padding_mode && in_v_d2) begin
                if (y_cnt_d2[0] == 1'b0) begin
                    // 偶数行写 RAM0
                    ram0_wraddr <= x_cnt_d2;
                    ram0_data   <= pix_curr_s1_stream;
                    ram0_wren   <= 1'b1;
                end else begin
                    // 奇数行写 RAM1
                    ram1_wraddr <= x_cnt_d2;
                    ram1_data   <= pix_curr_s1_stream;
                    ram1_wren   <= 1'b1;
                end
            end
        end
    end

    // ======================================================
    // 6) 给 window 的 in_valid：
    //    正常行：从第二行开始（跳过最顶行只有 padding 的那行）
    //    padding 行：bottom_valid_raw，再整体延迟一拍对齐 ram_q
    // ======================================================
    wire win_in_valid_normal = in_v_d2 && (y_cnt_d2 >= 16'd1);

    // padding 行：bottom_x_cnt = 0..WIDTH
    wire bottom_valid_raw = padding_mode && (bottom_x_cnt > 0) && (bottom_x_cnt <= WIDTH);

    // 为了和 RAM 的 q 对齐，padding 有效再打一拍
    reg bottom_valid_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bottom_valid_d1 <= 1'b0;
        else
            bottom_valid_d1 <= bottom_valid_raw;
    end

    wire win_in_valid = padding_mode ? bottom_valid_d1
                                     : win_in_valid_normal;

    // ======================================================
    // 7) window_3x3：负责横向 shift + 左右 padding
    // ======================================================
    window_3x3 #(
        .DATA_WIDTH(DATA_WIDTH),
        .WIDTH     (WIDTH),
        .HEIGHT    (HEIGHT)
    ) u_window_3x3 (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (win_in_valid),
        .pix_curr (pix_curr_s1),
        .pix_m1   (pix_m1_s1),
        .pix_m2   (pix_m2_s1),
        .win_valid(win_valid),
        .p00      (p00),
        .p01      (p01),
        .p02      (p02),
        .p10      (p10),
        .p11      (p11),
        .p12      (p12),
        .p20      (p20),
        .p21      (p21),
        .p22      (p22)
    );

endmodule
