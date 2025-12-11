`timescale 1ns/1ps

module tb_window_3x3();

// 参数定义
parameter DATA_WIDTH = 8;
parameter CLK_PERIOD = 40;  // 100MHz
parameter WIDTH = 10;       // 简化测试，使用较小宽度
parameter HEIGHT = 8;

// 信号声明
reg clk;
reg rst_n;
reg in_valid;
reg [DATA_WIDTH-1:0] pix_curr;
reg [DATA_WIDTH-1:0] pix_m1;
reg [DATA_WIDTH-1:0] pix_m2;

wire win_valid;
wire [DATA_WIDTH-1:0] p00, p01, p02;
wire [DATA_WIDTH-1:0] p10, p11, p12;
wire [DATA_WIDTH-1:0] p20, p21, p22;

// 时钟生成
always #(CLK_PERIOD/2) clk = ~clk;

// 实例化被测模块
window_3x3 #(
    .DATA_WIDTH(DATA_WIDTH),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) u_window_3x3 (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .pix_curr(pix_curr),
    .pix_m1(pix_m1),
    .pix_m2(pix_m2),
    .win_valid(win_valid),
    .p00(p00),
    .p01(p01),
    .p02(p02),
    .p10(p10),
    .p11(p11),
    .p12(p12),
    .p20(p20),
    .p21(p21),
    .p22(p22)
);

// 测试激励
integer i, j;
integer pixel_value = 1;
integer clock_count = 0;

initial begin
    // 初始化
    clk = 0;
    rst_n = 0;
    in_valid = 0;
    pix_curr = 0;
    pix_m1 = 0;
    pix_m2 = 0;
    pixel_value = 1;
    clock_count = 0;
    
    // 复位
    #(CLK_PERIOD*2);
    rst_n = 1;
    
    $display("=========================================");
    $display("开始测试 3x3 窗口模块");
    $display("=========================================\n");
    
    // 测试1: 正常数据流
    $display("测试1: 正常数据流测试");
    $display("时钟周期  in_valid 像素值(m2,m1,curr) 窗口有效 窗口内容");
    $display("-----------------------------------------------------------------");
    #(CLK_PERIOD/2);
    in_valid = 1;
    for (i = 0; i < 12; i = i + 1) begin
        pix_m2 = pixel_value;      // 行y-2
        pix_m1 = pixel_value + 1;  // 行y-1
        pix_curr = pixel_value + 2; // 行y
        
        #CLK_PERIOD;
        clock_count = clock_count + 1;
        
        // 显示窗口状态
        if (win_valid) begin
            $display("周期%2d:  %8b  (%3d,%3d,%3d)    %8b  (%3d,%3d,%3d)", 
                    clock_count, in_valid, pix_m2, pix_m1, pix_curr, win_valid,
                    p00, p01, p02);
            $display("                       p10,p11,p12: (%3d,%3d,%3d)", 
                    p10, p11, p12);
            $display("                       p20,p21,p22: (%3d,%3d,%3d)", 
                    p20, p21, p22);
        end
        else begin
            $display("周期%2d:  %8b  (%3d,%3d,%3d)    %8b  (等待窗口填充...)", 
                    clock_count, in_valid, pix_m2, pix_m1, pix_curr, win_valid);
        end
        
        pixel_value = pixel_value + 3;
    end
    
    // 测试2: 模拟padding（in_valid=0，但继续移位）
    $display("\n测试2: 模拟padding（in_valid=0）");
    $display("时钟周期  in_valid 像素值(m2,m1,curr) 窗口有效 窗口内容");
    $display("-----------------------------------------------------------------");
    
    in_valid = 0;
    for (i = 0; i < 5; i = i + 1) begin
        #CLK_PERIOD;
        clock_count = clock_count + 1;
        
        if (win_valid) begin
            $display("周期%2d:  %8b  (%3d,%3d,%3d)    %8b  (%3d,%3d,%3d)", 
                    clock_count, in_valid, 0, 0, 0, win_valid,
                    p00, p01, p02);
            $display("                       p10,p11,p12: (%3d,%3d,%3d)", 
                    p10, p11, p12);
            $display("                       p20,p21,p22: (%3d,%3d,%3d)", 
                    p20, p21, p22);
        end
    end
    
    // 测试3: 重新开始数据流
    $display("\n测试3: 重新开始数据流");
    $display("时钟周期  in_valid 像素值(m2,m1,curr) 窗口有效 窗口内容");
    $display("-----------------------------------------------------------------");
    
    in_valid = 1;
    for (i = 0; i < 8; i = i + 1) begin
        pix_m2 = 100 + i*3;        // 行y-2
        pix_m1 = 101 + i*3;        // 行y-1
        pix_curr = 102 + i*3;      // 行y
        
        #CLK_PERIOD;
        clock_count = clock_count + 1;
        
        if (win_valid) begin
            $display("周期%2d:  %8b  (%3d,%3d,%3d)    %8b  (%3d,%3d,%3d)", 
                    clock_count, in_valid, pix_m2, pix_m1, pix_curr, win_valid,
                    p00, p01, p02);
            $display("                       p10,p11,p12: (%3d,%3d,%3d)", 
                    p10, p11, p12);
            $display("                       p20,p21,p22: (%3d,%3d,%3d)", 
                    p20, p21, p22);
        end
    end
    
    // 结束测试
    #(CLK_PERIOD*5);
    $display("\n=========================================");
    $display("测试完成");
    $display("=========================================");
    $finish;
end

// 监控窗口变化
always @(posedge clk) begin
    if (rst_n) begin
        if (win_valid) begin
            // 可以在需要时添加更详细的监控
        end
    end
end

// 保存波形文件
initial begin
    $dumpfile("window_3x3.vcd");
    $dumpvars(0, tb_window_3x3);
end

endmodule