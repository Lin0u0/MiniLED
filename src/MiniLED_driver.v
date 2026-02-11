module MiniLED_driver
(
    input           I_clk       ,  // 50MHz      
    input           I_rst_n     ,   
    input [7:0]     I_led_light ,
    input [1:0]     I_led_mode  ,
    
    // 新增扩展控制信号
    input           I_zonal_en  ,   // 分区背光使能
    input           I_auto_bright,  // 自动亮度使能
    input [1:0]     I_sub_mode  ,   // 分区背光子模式
    	
    input           i_pix_clk   ,
    input [8:0]     cnt_360     ,
    input   	        flag_done   ,
    input [7:0]     I_bright    ,
    
    // LED 驱动输出
    output          LE          ,
    output          DCLK        ,   // 12.5M
    output          SDI         ,
    output          GCLK        ,
    output          scan1       ,
    output          scan2       ,
    output          scan3       , 
    output          scan4       
);

    wire clk25M;
    wire clk1M;
    wire sdbpflag;
    wire [9:0] wtaddr;
    wire [6:0] cntlatch;
    wire frame_flag;
    wire latch_flag;
    wire [95:0] datain;
    wire [15:0] wtdina;

    //===================================================================================
    // PLL 分频
    //===================================================================================
    SPI7001_25M_1M_rPLL SPI7001_25M_1M_rPLL_inst(
        .clkout         (clk25M     ),
        .clkoutd        (clk1M      ),
        .clkin          (I_clk      )
    );

    //===================================================================================
    // ramflag_In: 背光控制核心模块
    // 新增扩展控制接口支持更灵活的模式
    //===================================================================================
    ramflag_In u1_pro(
        .clk            (clk25M     ),
        .rst_n          (I_rst_n    ),
        .I_light_reg    (I_led_light),
        .I_bright       (I_bright   ),
        // 兼容旧接口
        .mode_selector  (I_led_mode ),
        // 新增扩展接口
        .I_zonal_en     (I_zonal_en ),
        .I_auto_bright  (I_auto_bright),
        .I_sub_mode     (I_sub_mode ),
        
        .sdbpflag_wire  (sdbpflag   ),
        .wtdina_wire    (wtdina     ),
        .wtaddr_wire    (wtaddr     ),
        .i_pix_clk      (i_pix_clk  ),
        .cnt_360        (cnt_360    ),
        .flag_done      (flag_done  )
    );

    //===================================================================================
    // SRAM 双缓冲
    //===================================================================================
    sram_top_gowin_top u2(
        .clka           (clk25M     ),
        .clkb           (clk1M      ),
        .sdbpflag       (sdbpflag   ),
        .wtaddr         (wtaddr     ),
        .wtdina         (wtdina     ),
        .rst_n          (I_rst_n    ),
        .latch_flag     (latch_flag ),
        .frame_flag     (frame_flag ),
        .datain         (datain     ),
        .cntlatch       (cntlatch   )
    );

    //===================================================================================
    // SPI7001 驱动接口
    //===================================================================================
    SPI7001_gowin_top u3(
        .clock          (clk25M     ),
        .clk_1M         (clk1M      ),
        .rst_n          (I_rst_n    ),
        .frame_f        (frame_flag ),
        .rgb_f          (latch_flag ),
        .rgb_data       (datain     ),
        .cntlatch       (cntlatch   ),
        .LE             (LE         ),
        .DCLK           (DCLK       ),
        .SDI            (SDI        ),
        .GCLK           (GCLK       ),
        .scan1          (scan1      ),
        .scan2          (scan2      ),
        .scan3          (scan3      ),
        .scan4          (scan4      ),
        .scan1_wire     (           ),
        .cnt_s          (10'b0      ),
        .cnt_ms         (10'b0      ),
        .cnt_us         (10'b0      )
    );

endmodule
