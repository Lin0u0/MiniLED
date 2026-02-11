
module block_360_pro(
	input 				i_pix_clk,
	input 				rst_n,
	input 				data_de,
	input [10:0]		pix_x,//1280*800 像素坐标);
	input [10:0]		pix_y,
	input [7:0]			data_gray,

	input [1:0] 		gray_mode,

	input 				r_Vsync_0,
	input 				r_Hsync_0,

	output reg [8:0]	cnt_360,//分区计数
	output reg 			flag_done,
	output reg [7:0]	buf_360_flatted	//读出数据
);

	parameter H_TOTAL	= 'd1280;
	parameter V_TOTAL	= 'd800;

	reg flag;

	reg [7:0] max_gray;//行最大值
	reg [7:0] ave_gray;//行均值

	reg [13:0] 		ave_sum_h;//行像素灰度求和
	reg [24*14-1:0] ave_sum_v;//行均值灰度求和
	
	// RMS 累加器（平方和）- 用于 RMS 算法模式
	// 灰度范围 0-255，平方范围 0-65025，需要 16bit
	reg [23:0] 		rms_sum_h;//行像素灰度平方和 (53 * 65025 < 2^24)
	reg [24*24-1:0] rms_sum_v;//列平方和累加 (24列 * 24bit)

	reg [5:0] cnt_h53;//行像素
	reg [4:0] cnt_h24;//行块 24X15
	reg [5:0] cnt_v53;//场像素

	reg  [24*8-1:0] max_buf;
	reg  [24*8-1:0] ave_buf;

	reg [7:0] buf_360_fore[360-1:0];
	reg [7:0] buf_360_fore1[360-1:0];
	reg [7:0] buf_360_fore2[360-1:0];
	reg [7:0] buf_360_fore3[360-1:0];
	reg [7:0] buf_360_fore4[360-1:0];
	reg [7:0] buf_360_fore5[360-1:0];
	reg [7:0] buf_360_fore6[360-1:0];

	wire [7:0] BL_max;
	wire [7:0] BL_ave;
	wire [7:0] BL_diff;
	wire [7:0] BL_correction;

	//余量裁剪
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			flag <= 0;
		end
		else if(pix_x > 'd3 && pix_x <= H_TOTAL - 'd4) begin //头尾各减去4个像素，根据延迟修正 ????????
			if(pix_y > 'd2 && pix_y <= V_TOTAL - 'd3)
			flag = 1'b1;
		end
		else begin
			flag <= 0;
		end
	end

	//行像素计数
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			cnt_h53 <= 0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52)	begin 
				cnt_h53 <= 'd0;
			end
			else begin
				cnt_h53 <= cnt_h53+1'b1;
			end
		end
		else if(!flag) begin
			cnt_h53 <= 0;
		end
	end

	//行块计数
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			cnt_h24 <= 0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52)	begin 
				if(cnt_h24 == 'd23) begin
					cnt_h24 <= 'd0;
				end
				else begin
					cnt_h24 <= cnt_h24 + 1'b1;
				end
			end	
		end
		else if(r_Hsync_0) begin
			cnt_h24 <= 0;
		end
	end

	//场像素计数
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			cnt_v53 <= 0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52 && cnt_h24 == 'd23) begin 
				if(cnt_v53 == 'd52) begin
					cnt_v53 <= 'd0;
				end
				else begin
					cnt_v53 <= cnt_v53 + 1'b1;
				end
			end	
		end		
	end

	//分区计数
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			cnt_360 <= 0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52 && cnt_v53 == 'd52) begin 
				if(cnt_360 == 'd359) begin
					cnt_360 <= 'd0;
				end
				else begin
					cnt_360 <= cnt_360 + 1'b1;
				end
			end	
		end
		else if(r_Vsync_0) begin
			cnt_360 <= 0;
		end
	end

	//最大值计算
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			max_gray <= 8'b0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd0)
				max_gray <= data_gray;
			else begin
				if(data_gray > max_gray) begin
					max_gray <= data_gray;
				end
			end
		end
	end

	//最大值赋值寄存
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			max_buf <= 192'b0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52) begin
				if(cnt_v53 == 'd52) begin
					max_buf[((cnt_h24) * 8) +:8] <= 8'b0;
				end
				else begin
					if(max_gray > max_buf[((cnt_h24) * 8) +:8]) begin
						max_buf[((cnt_h24) * 8) +:8] <= max_gray;
					end
				end
			end
		end
	end

	//均值计算
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			ave_sum_h <= 14'b0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd0) begin
				ave_sum_h <= data_gray;
			end
			else begin
				ave_sum_h <= ave_sum_h + data_gray;
			end
		end
	end
	
	// RMS 平方和计算
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			rms_sum_h <= 24'b0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd0) begin
				rms_sum_h <= data_gray * data_gray;
			end
			else begin
				rms_sum_h <= rms_sum_h + data_gray * data_gray;
			end
		end
	end

	//均值赋值寄存
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			ave_sum_v <= 336'b0;
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52) begin
				if(cnt_v53 == 'd52) begin
					ave_sum_v[((cnt_h24) * 14) +:14] <= 14'b0;
				end
				else begin
					ave_sum_v[((cnt_h24) * 14) +:14] <= ave_sum_v[((cnt_h24) * 14) +:14] + ave_sum_h / 'd52;
				end
			end
		end
	end
	
	// RMS 垂直方向累加
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			rms_sum_v <= 576'b0;//24*24
		end
		else if(data_de && flag) begin 
			if(cnt_h53 == 'd52) begin
				if(cnt_v53 == 'd52) begin
					rms_sum_v[((cnt_h24) * 24) +:24] <= 24'b0;
				end
				else begin
					// 累加平均平方值 (避免数值溢出，先除以 52)
					rms_sum_v[((cnt_h24) * 24) +:24] <= rms_sum_v[((cnt_h24) * 24) +:24] + rms_sum_h / 'd52;
				end
			end
		end
	end

	assign BL_max = (max_gray>max_buf[((cnt_h24) * 8) +:8]) ? max_gray : max_buf[((cnt_h24) * 8) +:8];
	assign BL_ave =ave_sum_v[((cnt_h24) * 14) +:14]/52;

	assign BL_diff= BL_max - BL_ave;
	assign BL_correction = (BL_diff + BL_diff / 255) / 255;
	
	// RMS 计算: sqrt(mean_of_squares)
	// 使用近似平方根计算 (53*53=2809 像素)
	wire [23:0] mean_square = rms_sum_v[((cnt_h24) * 24) +:24] / 'd52;// 平均平方值
	wire [7:0] BL_rms = isqrt_approx(mean_square);// 近似平方根

	// 简化的整数平方根近似函数
	// 使用牛顿迭代法的一次迭代: sqrt(x) ≈ (guess + x/guess) / 2
	// 初始猜测使用移位操作
	function [7:0] isqrt_approx;
		input [23:0] x;
		reg [7:0] guess;
		reg [15:0] quotient;
		begin
			// 初始猜测: 对于 0-65025 的输入，使用高 8bit 作为初始猜测
			if (x == 0)
				isqrt_approx = 0;
			else begin
				// 初始猜测: sqrt(x) ≈ x / 256 + 1 (当 x 较大时)
				// 简化为取高 8 位并加 1 避免 0
				guess = x[15:8] + 1;
				
				// 一次牛顿迭代: y = (y0 + x/y0) / 2
				quotient = x / guess;
				isqrt_approx = (guess + quotient[7:0]) >> 1;
			end
		end
	endfunction

	///buffer_360赋值最大值算法
	always@(posedge i_pix_clk or negedge rst_n) begin
		if(!rst_n) begin
			buf_360_flatted <= 0;
			flag_done <= 0;
		end else begin 
			if(cnt_h53 == 'd52 && cnt_v53 == 'd52 )begin 
					flag_done <= 1'b1;
					case(gray_mode)

						2'b00: begin								// RMS (Root Mean Square) 算法
							// 适合高对比度场景，平衡亮暗部分的细节保留
							buf_360_flatted <= BL_rms;
							
							// 同时更新历史缓冲区（用于时域滤波）
							buf_360_fore4[cnt_360] <= buf_360_fore3[cnt_360]; 
							buf_360_fore3[cnt_360] <= buf_360_fore2[cnt_360]; 									
							buf_360_fore2[cnt_360] <= buf_360_fore1[cnt_360];
							buf_360_fore1[cnt_360] <= buf_360_fore[cnt_360];
							buf_360_fore[cnt_360] <= BL_rms;
						end

					2'b01: begin								//设计均值修正最大值算法
						if(BL_diff > 200)begin
							buf_360_flatted <= (buf_360_fore[cnt_360] + buf_360_fore1[cnt_360] + 
												buf_360_fore2[cnt_360] + buf_360_fore3[cnt_360] + 
												buf_360_fore4[cnt_360] + (BL_max + BL_ave * 3) / 8 ) / 6;
						
							buf_360_fore4[cnt_360] <= buf_360_fore3[cnt_360]; 
							buf_360_fore3[cnt_360] <= buf_360_fore2[cnt_360]; 									
							buf_360_fore2[cnt_360] <= buf_360_fore1[cnt_360];
							buf_360_fore1[cnt_360] <= buf_360_fore[cnt_360];
							buf_360_fore[cnt_360] <= (BL_max + BL_ave * 3) / 8;
						end 
						else begin
							buf_360_flatted <= (buf_360_fore[cnt_360] + buf_360_fore1[cnt_360] + 
												buf_360_fore2[cnt_360] + buf_360_fore3[cnt_360] + 
												buf_360_fore4[cnt_360] + (BL_max * 3 + BL_ave * 1) / 4) / 6; 
							

							buf_360_fore4[cnt_360] <= buf_360_fore3[cnt_360]; 									
							buf_360_fore3[cnt_360] <= buf_360_fore2[cnt_360]; 
							buf_360_fore2[cnt_360] <= buf_360_fore1[cnt_360];
							buf_360_fore1[cnt_360] <= buf_360_fore[cnt_360];
							buf_360_fore [cnt_360] <= BL_max;
						end
					end							

					2'b10: begin
						buf_360_flatted <= BL_max;
					end

					2'b11: 	begin 
						if(BL_diff > 200) begin
							buf_360_flatted <= (BL_max + BL_ave) / 4;			//设计均值修正最大值算法
						end
						else begin
							buf_360_flatted <= BL_max;
						end
					end		 

					default: begin
						buf_360_flatted <= BL_max;
					end
				endcase
			end else begin
				flag_done <= 0;	
			end
		end
	end






endmodule