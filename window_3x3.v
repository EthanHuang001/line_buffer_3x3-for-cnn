module window_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter WIDTH      = 640,
    parameter HEIGHT     = 480
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    input  wire                   in_valid,     // 对齐后的"行流"有效
    input  wire [DATA_WIDTH-1:0]  pix_curr,     // 当前行 y
    input  wire [DATA_WIDTH-1:0]  pix_m1,       // y-1 行
    input  wire [DATA_WIDTH-1:0]  pix_m2,       // y-2 行
    
    output reg                   win_valid,    // 3x3 窗口有效
    output wire [DATA_WIDTH-1:0]  p00, p01, p02,
    output wire [DATA_WIDTH-1:0]  p10, p11, p12,
    output wire [DATA_WIDTH-1:0]  p20, p21, p22
);

// 内部寄存器声明
reg [DATA_WIDTH-1:0] p00_reg, p01_reg, p02_reg;
reg [DATA_WIDTH-1:0] p10_reg, p11_reg, p12_reg;
reg [DATA_WIDTH-1:0] p20_reg, p21_reg, p22_reg;

// 窗口有效标志寄存器
reg win_valid_reg;
// 输入数据选择器
wire [DATA_WIDTH-1:0] pix_m2_in = in_valid ? pix_m2 : {DATA_WIDTH{1'b0}};
wire [DATA_WIDTH-1:0] pix_m1_in = in_valid ? pix_m1 : {DATA_WIDTH{1'b0}};
wire [DATA_WIDTH-1:0] pix_curr_in = in_valid ? pix_curr : {DATA_WIDTH{1'b0}};

// 主移位逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位所有寄存器
        p00_reg <= {DATA_WIDTH{1'b0}};
        p01_reg <= {DATA_WIDTH{1'b0}};
        p02_reg <= {DATA_WIDTH{1'b0}};
        
        p10_reg <= {DATA_WIDTH{1'b0}};
        p11_reg <= {DATA_WIDTH{1'b0}};
        p12_reg <= {DATA_WIDTH{1'b0}};
        
        p20_reg <= {DATA_WIDTH{1'b0}};
        p21_reg <= {DATA_WIDTH{1'b0}};
        p22_reg <= {DATA_WIDTH{1'b0}};
        
        win_valid_reg <= 1'b0;
    end
    else begin
        // 第一行移位: pix_m2
        p02_reg <= p01_reg;  // p01 -> p02
        p01_reg <= p00_reg;  // p00 -> p01
        p00_reg <= pix_m2_in; // 新输入 -> p00
        
        // 第二行移位: pix_m1
        p12_reg <= p11_reg;  // p11 -> p12
        p11_reg <= p10_reg;  // p10 -> p11
        p10_reg <= pix_m1_in; // 新输入 -> p10
        
        // 第三行移位: pix_curr
        p22_reg <= p21_reg;  // p21 -> p22
        p21_reg <= p20_reg;  // p20 -> p21
        p20_reg <= pix_curr_in; // 新输入 -> p20
        
        // 窗口有效信号生成
        // 当窗口填充了2个有效列时，窗口开始有效
        win_valid_reg <= in_valid;
		win_valid <= win_valid_reg;
    end
end

// 输出连接
assign p02 = p00_reg;
assign p01 = p01_reg;
assign p00 = p02_reg;
assign p12 = p10_reg;
assign p11 = p11_reg;
assign p10 = p12_reg;
assign p22 = p20_reg;
assign p21 = p21_reg;
assign p20 = p22_reg;

endmodule