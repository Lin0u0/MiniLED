//===================================================================================
// Module: key_debounce
// Description: 按键消抖模块，使用计数器实现10ms消抖
//===================================================================================
module key_debounce (
    input        clk,       // 系统时钟 (50MHz)
    input        rst_n,     // 复位信号
    input        key_in,    // 按键输入 (低电平有效)
    output reg   key_out,   // 消抖后的按键输出
    output reg   key_posedge,  // 按键上升沿 (释放)
    output reg   key_negedge   // 按键下降沿 (按下)
);

    // 50MHz时钟，10ms = 500000个时钟周期
    localparam DEBOUNCE_CNT = 20'd500000;
    
    reg [19:0] cnt;
    reg key_in_d0, key_in_d1, key_in_d2;
    reg key_stable;
    
    // 同步按键信号到时钟域
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_in_d0 <= 1'b1;  // 按键默认高电平(释放)
            key_in_d1 <= 1'b1;
            key_in_d2 <= 1'b1;
        end else begin
            key_in_d0 <= key_in;
            key_in_d1 <= key_in_d0;
            key_in_d2 <= key_in_d1;
        end
    end
    
    // 消抖计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 20'd0;
            key_stable <= 1'b1;
        end else begin
            if (key_in_d2 != key_stable) begin
                // 按键状态变化，开始计数
                if (cnt < DEBOUNCE_CNT) begin
                    cnt <= cnt + 1'b1;
                end else begin
                    // 计数达到阈值，确认状态变化
                    cnt <= 20'd0;
                    key_stable <= key_in_d2;
                end
            end else begin
                // 状态稳定，重置计数器
                cnt <= 20'd0;
            end
        end
    end
    
    // 输出及边沿检测
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_out <= 1'b1;
            key_posedge <= 1'b0;
            key_negedge <= 1'b0;
        end else begin
            key_out <= key_stable;
            key_posedge <= key_stable & ~key_out;  // 0->1
            key_negedge <= ~key_stable & key_out;  // 1->0
        end
    end

endmodule
