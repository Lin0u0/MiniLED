//===================================================================================
// Module: ramflag_In
// Description: LED 背光控制核心模块
// 支持按键控制的背光模式：
//   - zonal_en:    分区背光开关 (LED3)
//   - auto_bright: 自动亮度开关 (LED2) 
//   - sub_mode:    分区背光子模式 00-11 (LED1:0)
//===================================================================================
module ramflag_In(
    input           clk             ,   // 25Mclk
    input           rst_n           ,
    
    input           i_pix_clk       ,
    input [7:0]     I_light_reg     ,
    input [8:0]     cnt_360         ,
    input           flag_done       ,
    
    // 兼容旧接口
    input [1:0]     mode_selector   ,
    input [7:0]     I_bright        ,
    
    // 新增扩展控制接口
    input           I_zonal_en      ,   // 分区背光使能 (1=开启)
    input           I_auto_bright   ,   // 自动亮度使能 (1=开启)
    input [1:0]     I_sub_mode      ,   // 分区背光子模式

    output          sdbpflag_wire   ,
    output [15:0]   wtdina_wire     ,
    output [9:0]    wtaddr_wire
);

    reg [11:0]      cnt;                // 用于延迟 1250 个 dclk 等待配置寄存器时间
    reg [30:0]      cnt1;               // 用于周期性发送 sdbpflag 信号
    reg [9:0]       cnt2;               // 用于每帧暂存时间
    reg [13:0]      cnt3;               // 每一轮 addr 自加 +1
    reg             flag;               // 标志配置寄存器结束
    reg             sdbpflag;
    reg [15:0]      wtdina;             // 灯珠驱动亮度值
    reg [9:0]       wtaddr;             // 灯珠驱动地址
    reg [7:0]       light_reg[360-1:0]; // 缓存灯珠数据
    reg [8:0]       cnt_360_delay;      // 对灰度数据坐标进行延迟修正

    assign sdbpflag_wire = sdbpflag;
    assign wtdina_wire   = wtdina;
    assign wtaddr_wire   = wtaddr;

    //===================================================================================
    // 初始化：cnt 记满后视为配置寄存器完毕
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag <= 0;
            cnt  <= 0;
        end else if (cnt < 2500) begin
            flag <= 0;
            cnt  <= cnt + 1;
        end else if (cnt == 2500) begin
            flag <= 1;
        end
    end

    //===================================================================================
    // cnt1: 计数 sdbpflag 的周期 (约 16.8ms)
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt1 <= 0;
        end else if (cnt1 >= 420_000) begin
            cnt1 <= 0;
        end else begin
            cnt1 <= cnt1 + 1;
        end
    end

    //===================================================================================
    // cnt2: 流水灯状态下每颗灯点亮的持续时间
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt2 <= 0;
        end else if (cnt1 == 0 && flag) begin 
            if (cnt2 == 19) begin
                cnt2 <= 0;
            end else begin
                cnt2 <= cnt2 + 1;
            end
        end
    end

    //===================================================================================
    // cnt3: 点亮灯珠的位置计数 (0-359)
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt3 <= 0;
        end else if (cnt1 == 1 && cnt2 == 0 && flag) begin
            if (cnt3 >= 359) begin
                cnt3 <= 0;
            end else begin
                cnt3 <= cnt3 + 1;
            end
        end
    end

    //===================================================================================
    // 控制输出信号 sdbpflag
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdbpflag <= 0;
        end else if (cnt1 == 1 && flag) begin
            sdbpflag <= 1;
        end else if (cnt1 == 30 && flag) begin
            sdbpflag <= 0;  
        end
    end

    //===================================================================================
    // 控制输出信号 wtaddr
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wtaddr <= 0;
        end else if (cnt1 == 3) begin
            wtaddr <= 0;
        end else if (cnt1 > 4 && cnt1 <= 4 + 360 && flag) begin
            wtaddr <= wtaddr + 1;
        end else if (cnt1 > 4 + 360) begin
            wtaddr <= 0; 
        end
    end

    //===================================================================================
    // 缓存输入的灯珠灰度值
    //===================================================================================
    always @(posedge i_pix_clk) begin
        if (!rst_n) begin
            cnt_360_delay <= 0;
        end else if (flag_done) begin
            light_reg[cnt_360_delay] <= I_light_reg;
            cnt_360_delay <= cnt_360;
        end
    end

    //===================================================================================
    // 辅助函数：检查地址是否在左半屏 (0-11列)
    //===================================================================================
    function automatic is_left_half;
        input [9:0] addr;
        reg [4:0] col;
        begin
            col = addr % 24;
            is_left_half = (col >= 0 && col <= 11);
        end
    endfunction

    //===================================================================================
    // 背光亮度计算 (新的灵活控制逻辑)
    //===================================================================================
    reg [15:0] base_brightness;     // 基础亮度值
    reg [15:0] final_brightness;    // 最终亮度值
    
    // 第一步：根据 zonal_en 和 sub_mode 计算基础亮度
    always @(*) begin
        if (!I_zonal_en) begin
            // 分区背光关闭：全区固定亮度
            base_brightness = 16'd224 * 16'd255;  // 0xE0 * 255
        end else begin
            // 分区背光开启
            case (I_sub_mode)
                2'b00: begin  // 子模式 00：左半屏固定，右半屏分区
                    if (is_left_half(wtaddr))
                        base_brightness = 16'd224 * 16'd255;
                    else
                        base_brightness = light_reg[wtaddr] * 16'd255;
                end
                
                2'b01: begin  // 子模式 01：右半屏固定，左半屏分区
                    if (!is_left_half(wtaddr))
                        base_brightness = 16'd224 * 16'd255;
                    else
                        base_brightness = light_reg[wtaddr] * 16'd255;
                end
                
                2'b10: begin  // 子模式 10：棋盘格模式 (偶数分区固定)
                    if ((wtaddr[0] ^ wtaddr[4]) == 1'b0)  // 简单的棋盘判断
                        base_brightness = 16'd224 * 16'd255;
                    else
                        base_brightness = light_reg[wtaddr] * 16'd255;
                end
                
                2'b11: begin  // 子模式 11：纯分区背光 (360区独立)
                    base_brightness = light_reg[wtaddr] * 16'd255;
                end
                
                default: base_brightness = light_reg[wtaddr] * 16'd255;
            endcase
        end
    end
    
    // 第二步：根据 auto_bright 应用环境光调节
    always @(*) begin
        if (I_auto_bright && I_zonal_en) begin
            // 自动亮度开启且分区背光开启：乘以环境光系数
            final_brightness = (base_brightness * I_bright) >> 8;
        end else begin
            // 自动亮度关闭或分区背光关闭：保持基础亮度
            final_brightness = base_brightness;
        end
    end

    //===================================================================================
    // 输出控制 (时序逻辑)
    //===================================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wtdina <= 0;
        end else begin
            if (cnt1 > 3 && cnt1 <= 364 && flag) begin
                wtdina <= final_brightness;
            end else begin
                wtdina <= 0;
            end
        end
    end

endmodule
