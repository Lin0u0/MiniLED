module miniled_top
(
    // LVDS 控制
    input           I_clk       ,  // 50MHz      
    input           I_rst_n     ,
    output  [3:0]   O_led       , 
    input           I_clkin_p   ,  // LVDS Input
    input           I_clkin_n   ,  // LVDS Input
    input   [3:0]   I_din_p     ,  // LVDS Input
    input   [3:0]   I_din_n     ,  // LVDS Input    
    output          O_clkout_p  ,
    output          O_clkout_n  ,
    output  [3:0]   O_dout_p    ,
    output  [3:0]   O_dout_n    ,
    
    // 拨码开关控制背光功能 (低电平有效)
    input           sw_zonal_en ,   // SW1: 分区背光开关 (0=开启, 1=关闭)
    input           sw_auto_bright, // SW2: 自动亮度开关 (0=开启, 1=关闭)
    
    // 按键控制算法模式 (低电平有效，带消抖)
    input           key_rms     ,   // KEY1: RMS 算法
    input           key_max     ,   // KEY2: Max 算法  
    input           key_ave     ,   // KEY3: Ave 算法
    input           key_cor     ,   // KEY4: Cor 算法
    
    // LED 灯板控制
    output          LE          ,
    output          DCLK        ,   // 12.5M
    output          SDI         ,
    output          GCLK        ,
    output          scan1       ,
    output          scan2       ,
    output          scan3       , 
    output          scan4       ,
    
    // IIC 光线传感器控制
    inout           sda         ,
    output          scl         
);

    //======================================================
    // 背光控制状态 (直接来自拨码开关，实时响应)
    //======================================================
    // zonal_en:    分区背光开关 (1=开启, 0=关闭) -> LED3
    // auto_bright: 自动亮度开关 (1=开启, 0=关闭) -> LED2
    // 注意：拨码开关低电平有效，所以取反
    
    wire        zonal_en    = ~sw_zonal_en;     // SW1=0 时开启分区背光
    wire        auto_bright = ~sw_auto_bright;  // SW2=0 时开启自动亮度
    reg  [1:0]  sub_mode;                       // 分区背光子模式
    
    // LED 显示逻辑
    // LED3: zonal_en (分区背光开关)
    // LED2: auto_bright (自动亮度开关)
    // LED1:0: 算法模式指示 (RMS=00, Max=01, Ave=10, Cor=11)
    assign O_led[3] = zonal_en;
    assign O_led[2] = auto_bright;
    
    //======================================================
    // 算法模式控制 (按键选择，带消抖)
    //======================================================
    reg [1:0] gray_mode;
    
    // 按键消抖实例化
    wire key_rms_out, key_rms_posedge, key_rms_negedge;
    wire key_max_out, key_max_posedge, key_max_negedge;
    wire key_ave_out, key_ave_posedge, key_ave_negedge;
    wire key_cor_out, key_cor_posedge, key_cor_negedge;
    
    key_debounce debounce_key_rms (
        .clk        (I_clk),
        .rst_n      (I_rst_n),
        .key_in     (key_rms),
        .key_out    (key_rms_out),
        .key_posedge(key_rms_posedge),
        .key_negedge(key_rms_negedge)
    );
    
    key_debounce debounce_key_max (
        .clk        (I_clk),
        .rst_n      (I_rst_n),
        .key_in     (key_max),
        .key_out    (key_max_out),
        .key_posedge(key_max_posedge),
        .key_negedge(key_max_negedge)
    );
    
    key_debounce debounce_key_ave (
        .clk        (I_clk),
        .rst_n      (I_rst_n),
        .key_in     (key_ave),
        .key_out    (key_ave_out),
        .key_posedge(key_ave_posedge),
        .key_negedge(key_ave_negedge)
    );
    
    key_debounce debounce_key_cor (
        .clk        (I_clk),
        .rst_n      (I_rst_n),
        .key_in     (key_cor),
        .key_out    (key_cor_out),
        .key_posedge(key_cor_posedge),
        .key_negedge(key_cor_negedge)
    );
    
    // 算法模式状态机 (按键切换，优先级: RMS > Max > Ave > Cor)
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            gray_mode <= 2'b01;     // 默认 Mean-Corrected Max
        end else begin
            if (key_rms_negedge)
                gray_mode <= 2'b00;  // RMS
            else if (key_max_negedge)
                gray_mode <= 2'b01;  // Max
            else if (key_ave_negedge)
                gray_mode <= 2'b10;  // Ave
            else if (key_cor_negedge)
                gray_mode <= 2'b11;  // Cor
        end
    end
    
    // LED1:0 显示当前算法模式
    assign O_led[1:0] = gray_mode;
    
    //======================================================
    // 子模式切换 (使用未被按键占用的拨码开关组合或固定值)
    // 简化设计：子模式固定为 11 (纯分区背光)
    // 如需更多子模式，可通过按键长按/组合实现
    //======================================================
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            sub_mode <= 2'b11;  // 默认纯分区背光
    end
    
    // 组合成兼容旧接口的 led_mode
    wire [1:0] led_mode = (~zonal_en)      ? 2'b00 :   // 全区固定
                          (auto_bright)   ? 2'b10 :   // 自动调光
                          (sub_mode[1])   ? 2'b11 :   // 纯分区
                                            2'b01;    // 半区

    //======================================================
    // 内部信号
    //======================================================
    wire [7:0]  r_R_0;
    wire [7:0]  r_G_0;
    wire [7:0]  r_B_0;
    wire        r_Vsync_0;
    wire        r_Hsync_0;
    wire        r_DE_0;
    wire        rx_sclk;
    wire [7:0]  led_light;
    wire [7:0]  data_gray;
    wire [10:0] pix_x;
    wire [10:0] pix_y;
    wire [8:0]  cnt_360;
    wire        flag_done;
    wire [7:0]  bright_data;

    //======================================================
    // LVDS Receiver
    //======================================================
    LVDS_7to1_RX_Top LVDS_7to1_RX_Top_inst
    (
        .I_rst_n        (I_rst_n    ),
        .I_clkin_p      (I_clkin_p  ),
        .I_clkin_n      (I_clkin_n  ),
        .I_din_p        (I_din_p    ),
        .I_din_n        (I_din_n    ),
        .O_pllphase     (           ),
        .O_pllphase_lock(           ),
        .O_clkpat_lock  (           ),
        .O_pix_clk      (rx_sclk    ),  
        .O_vs           (r_Vsync_0  ),
        .O_hs           (r_Hsync_0  ),
        .O_de           (r_DE_0     ),
        .O_data_r       (r_R_0      ),
        .O_data_g       (r_G_0      ),
        .O_data_b       (r_B_0      )
    );

    //======================================================
    // LVDS TX
    //======================================================
    LVDS_7to1_TX_Top LVDS_7to1_TX_Top_inst
    (
        .I_rst_n       (I_rst_n     ),
        .I_pix_clk     (rx_sclk     ),
        .I_vs          (r_Vsync_0   ), 
        .I_hs          (r_Hsync_0   ),
        .I_de          (r_DE_0      ),
        .I_data_r      (r_R_0       ),
        .I_data_g      (r_G_0       ),
        .I_data_b      (r_B_0       ), 
        .O_clkout_p    (O_clkout_p  ), 
        .O_clkout_n    (O_clkout_n  ),
        .O_dout_p      (O_dout_p    ),    
        .O_dout_n      (O_dout_n    ) 
    );

    //======================================================
    // MiniLED_driver
    //======================================================
    MiniLED_driver MiniLED_driver_inst
    (
        .I_clk          (I_clk      ),
        .I_rst_n        (I_rst_n    ),
        .I_led_light    (led_light  ),
        .I_led_mode     (led_mode   ),
        .I_zonal_en     (zonal_en   ),
        .I_auto_bright  (auto_bright),
        .I_sub_mode     (sub_mode   ),
        
        .i_pix_clk      (rx_sclk    ),
        .cnt_360        (cnt_360    ),
        .flag_done      (flag_done  ),
        .I_bright       (bright_data),
        
        .LE             (LE         ),
        .DCLK           (DCLK       ),
        .SDI            (SDI        ),
        .GCLK           (GCLK       ),
        .scan1          (scan1      ),
        .scan2          (scan2      ),
        .scan3          (scan3      ), 
        .scan4          (scan4      )       
    );

    //======================================================
    // RGB2GRAY
    //======================================================
    rgb_to_data_gray rtg(
        .i_pix_clk      (rx_sclk    ),
        .rst_n          (I_rst_n    ),
        .data_de        (r_DE_0     ),
        .data_r         (r_R_0      ),
        .data_g         (r_G_0      ),
        .data_b         (r_B_0      ),
        .data_gray      (data_gray  ),
        .pix_x          (pix_x      ),
        .pix_y          (pix_y      )
    );

    //======================================================
    // I2C_AP3216
    //======================================================
    AP3216_driver AP3216_driver_inst(
        .I_clk          (I_clk      ),
        .I_reset        (I_rst_n    ),
        .sda            (sda        ),
        .scl            (scl        ),
        .O_bright_data  (bright_data)
    );

    //======================================================
    // 背光算法
    //======================================================
    block_360_pro backlight_algorithm_inst(
        .i_pix_clk      (rx_sclk    ),
        .rst_n          (I_rst_n    ),
        .data_de        (r_DE_0     ),
        .pix_x          (pix_x      ),
        .pix_y          (pix_y      ),
        .data_gray      (data_gray  ),
        .r_Hsync_0      (r_Hsync_0  ),
        .r_Vsync_0      (r_Vsync_0  ),
        .gray_mode      (gray_mode  ),
        .flag_done      (flag_done  ),
        .cnt_360        (cnt_360    ),
        .buf_360_flatted(led_light  )
    );

endmodule
