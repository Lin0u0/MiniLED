# MiniLED Zonal Backlight Controller

An FPGA-based MiniLED zonal backlight controller designed for the Gowin MiniLED development kit. This project implements real-time video processing to calculate grayscale values for 360 backlight zones and controls the backlight panel via SPI to enhance display contrast and save energy.

## Features

- **360-Zone Dynamic Backlight Control** (24×15 lamp beads arrangement)
- **Real-time Video Processing** for 1280×800 @ 60Hz input
- **LVDS 7:1 Video Interface** for seamless video passthrough
- **Three Backlight Algorithms**: Mean-corrected max, Maximum, and Correction modes
- **Ambient Light Sensing** with auto-brightness adjustment (AP3216 via I2C)
- **Four Display Modes**: Full backlight, Half-screen comparison, Zonal with auto-brightness, Zonal only

## Hardware Specifications

| Component | Specification |
|-----------|---------------|
| FPGA | Gowin GW2A-LV55PG484C8/I7 (GW2A-55 series) |
| LCD Panel | 1280×800 @ 60Hz |
| Backlight | 360 zones (24 columns × 15 rows) |
| Video Input/Output | LVDS 7:1 |
| Ambient Light Sensor | AP3216 (I2C interface) |
| LED Driver | SPI7001 (SPI interface) |

## Project Structure

```
MiniLED/
├── miniled.gprj              # Gowin FPGA project configuration
├── src/
│   ├── miniled_top.v         # Top-level module
│   ├── miniled.cst           # Physical constraints (pin assignments)
│   ├── miniled.sdc           # Timing constraints
│   ├── MiniLED_driver.v      # LED panel driver controller
│   ├── ramflag_In.v          # Backlight data buffer & mode controller
│   ├── SPI7001_gowin.vp      # SPI7001 LED driver IP
│   ├── SPI7001_sim.v         # SPI7001 simulation model
│   ├── sram_top_gowin_top_sim.v  # SRAM controller
│   ├── algorithm/            # Backlight processing algorithms
│   │   ├── rgb_to_gray.v     # RGB to grayscale conversion
│   │   └── block_360_pro.v   # 360-zone backlight algorithm
│   ├── lvds_7to1_rx/         # LVDS receiver modules
│   ├── lvds_7to1_tx/         # LVDS transmitter modules
│   ├── i2c/                  # I2C interface & sensor driver
│   └── gowin_rpll/           # Clock PLL IP
├── README.md                 # This file
└── LICENSE                   # MIT License
```

## Architecture Overview

```
Video Input (LVDS) → LVDS RX → RGB to Gray → Backlight Algorithm → LED Driver → Backlight Panel
                          ↓
                    Video Output (LVDS) → LCD Panel
                          ↓
              Ambient Light Sensor (I2C) → Auto-brightness
```

### Key Modules

1. **RGB to Grayscale** (`rgb_to_gray.v`)
   - Converts 8-bit RGB to grayscale using NTSC formula: `Gray = (306×R + 601×G + 117×B) / 1024`
   - Generates pixel coordinates for zone mapping

2. **360-Zone Backlight Algorithm** (`block_360_pro.v`)
   - Partitions 1280×800 display into 360 zones (53×53 pixels per zone)
   - Three selectable modes via `gray_mode`:
     - **Mode 01** (default): Mean-corrected maximum with 6-frame temporal smoothing
     - **Mode 10**: Maximum value per zone
     - **Mode 11**: Correction based on max-average difference

3. **LED Panel Driver**
   - Buffers 360-zone brightness values
   - Supports 4 display modes via `led_mode`
   - Drives SPI7001 LED driver IC

4. **Ambient Light Sensor** (`AP3216_driver.v`)
   - I2C communication with AP3216 sensor
   - Smooth brightness adjustment with 2-second detection delay

## Clock Domains

| Clock | Frequency | Purpose |
|-------|-----------|---------|
| I_clk | 50MHz | System clock (main control logic) |
| rx_sclk | ~70MHz | Pixel clock (from LVDS RX, video processing) |
| clk25M | 25MHz | LED driver clock |
| clk1M | 1MHz | SPI7001 low-speed control |
| scl | 400kHz | I2C clock |

## Build Instructions

### Requirements
- Gowin Cloud Development Environment (Gowin IDE) V1.9.10.02 or later
- Target Device: GW2A-55 series (GW2A-LV55PG484C8/I7)

### Steps
1. Open `miniled.gprj` in Gowin IDE
2. The project includes all Verilog sources, constraints, and IP cores
3. Run synthesis and implementation
4. Program the FPGA via Gowin programmer

## Pin Assignments

| Signal | Pin | Type | Description |
|--------|-----|------|-------------|
| I_clkin_p/n | A15,B15 | LVDS25 | LVDS clock input |
| I_din_p/n[3:0] | A2,A3 / B6,A6 / A9,A10 / A11,A12 | LVDS25 | LVDS data input |
| O_clkout_p/n | C9,C10 | LVDS25 | LVDS clock output |
| O_dout_p/n[3:0] | A22,B22 / C14,C15 / A17,B17 / C18,C19 | LVDS25 | LVDS data output |
| LE | N19 | LVCMOS25 | LED latch enable |
| DCLK | C20 | LVCMOS25 | LED data clock (12.5MHz) |
| SDI | F19 | LVCMOS25 | LED serial data |
| GCLK | F20 | LVCMOS25 | LED global clock |
| scan1-4 | E20,D20,B21,C21 | LVCMOS25 | LED scan control |
| sda | E22 | LVCMOS25 | I2C data (AP3216) |
| scl | F22 | LVCMOS25 | I2C clock (AP3216) |
| I_clk | M19 | LVCMOS25 | System clock (50MHz) |
| I_rst_n | AB3 | LVCMOS15 | Reset (active low) |

## Control Signals

| Signal | Description |
|--------|-------------|
| max_mode | Select maximum algorithm |
| ave_mode | Select average algorithm |
| cor_mode | Select correction algorithm |
| led_mode[1:0] | LED display mode (00=Full, 01=Half-screen, 10=Zonal+Auto, 11=Zonal) |
| O_led[3:0] | Mode indicator LEDs |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
