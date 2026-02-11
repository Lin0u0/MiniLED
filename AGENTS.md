# MiniLED Zonal Backlight FPGA Project

## Project Overview

This is an FPGA-based MiniLED zonal backlight controller project designed for the Gowin MiniLED development kit. The project implements real-time video processing to calculate grayscale values for 360 backlight zones (24×15 lamp beads arrangement) and controls the backlight panel via SPI to enhance display contrast and save energy.

**Key Specifications:**
- Target Device: Gowin GW2A-LV55PG484C8/I7 (GW2A-55 series FPGA)
- Video Resolution: 1280×800 @ 60Hz
- Backlight Zones: 360 zones (24 columns × 15 rows)
- Input/Output: LVDS 7:1 video interface
- Development Kit: Gowin MiniLED zonal backlight development kit (LCD + backlight board)

## Technology Stack

- **Hardware Description Language**: Verilog HDL
- **Target Platform**: Gowin FPGA (GW2A-55)
- **Development Tool**: Gowin IDE (V1.9.10.02 or compatible)
- **Project Format**: `.gprj` (Gowin FPGA Project)
- **License**: MIT License

## Project Structure

```
MiniLED/
├── miniled.gprj              # Gowin FPGA project configuration
├── src/
│   ├── miniled_top.v         # Top-level module (main entry point)
│   ├── miniled.cst           # Physical constraints (pin assignments)
│   ├── miniled.sdc           # Timing constraints
│   ├── MiniLED_driver.v      # LED panel driver controller
│   ├── ramflag_In.v          # Backlight data buffer & mode controller
│   ├── SPI7001_gowin.vp      # SPI7001 LED driver IP (encrypted)
│   ├── SPI7001_sim.v         # SPI7001 simulation model
│   ├── sram_top_gowin_top_sim.v  # SRAM controller for LED data
│   ├── algorithm/            # Backlight processing algorithms
│   │   ├── rgb_to_gray.v     # RGB to grayscale conversion
│   │   └── block_360_pro.v   # 360-zone backlight algorithm
│   ├── lvds_7to1_rx/         # LVDS 7:1 receiver modules
│   │   ├── lvds_7to1_rx_top.v
│   │   ├── LVDS71RX_1CLK8DATA.v
│   │   ├── bit_align_ctl.v
│   │   ├── word_align_ctl.v
│   │   ├── lvds_7to1_rx_defines.v
│   │   └── gowin_rpll2/      # RX PLL IP
│   ├── lvds_7to1_tx/         # LVDS 7:1 transmitter modules
│   │   ├── lvds_7to1_tx_top.v
│   │   ├── ip_gddr71tx.v
│   │   ├── lvds_7to1_tx_defines.v
│   │   └── gowin_rpll2/      # TX PLL IP
│   ├── i2c/                  # I2C interface & sensor driver
│   │   ├── i2c_top.v
│   │   ├── i2c_controller.v
│   │   └── AP3216_driver.v   # AP3216 ambient light sensor driver
│   └── gowin_rpll/           # Main clock PLL IP
│       └── gowin_rpll.v
├── README.md                 # Chinese documentation
├── README_EN.md              # English documentation
└── LICENSE                   # MIT License
```

## Module Architecture

### 1. Top Module (`miniled_top.v`)
The top-level module integrates all subsystems:
- **LVDS RX**: Receives 1280×800 video via LVDS interface
- **LVDS TX**: Passes through video to LCD panel
- **RGB to Gray**: Converts RGB data to grayscale (NTSC formula)
- **Backlight Algorithm** (`block_360_pro`): Calculates 360-zone backlight values
- **MiniLED Driver**: Controls LED panel via SPI protocol
- **I2C Sensor**: Reads ambient light from AP3216 sensor

### 2. Backlight Algorithm (`algorithm/`)

#### RGB to Grayscale (`rgb_to_gray.v`)
- Converts 8-bit RGB to grayscale using NTSC standard formula:
  - `Gray = (306×R + 601×G + 117×B) / 1024`
- Generates pixel coordinates (pix_x, pix_y) for zone mapping

#### 360-Zone Backlight (`block_360_pro.v`)
Partitions 1280×800 display into 360 zones (24×15):
- Horizontal: 1280/24 ≈ 53 pixels per zone
- Vertical: 800/15 ≈ 53 pixels per zone

**Algorithm Modes (selectable via `gray_mode`):**
1. **Mode 01** (Mean-Corrected Max - Default): Combines max and average values with temporal smoothing
2. **Mode 10** (Maximum): Uses maximum grayscale value per zone
3. **Mode 11** (Correction): Applies correction based on difference between max and average

### 3. LVDS Interface (`lvds_7to1_rx/`, `lvds_7to1_tx/`)

Implements 7:1 LVDS video serialization/deserialization:
- **RX**: Receives LVDS video, extracts RGB data, VSYNC, HSYNC, DE
- **TX**: Re-serializes RGB data for LCD panel output
- **Formats**: Supports VESA/JEIDA mapping, RGB888/RGB666
- **Clock**: Uses 3.5× pixel clock for serialization

Configuration via `lvds_7to1_rx_defines.v` and `lvds_7to1_tx_defines.v`:
```verilog
`define RX_ONE_CHANNEL    // Single channel mode
`define RX_VESA           // VESA color mapping
`define RX_RGB888         // 24-bit color
`define RX_USE_RPLL       // Use rPLL for clock
```

### 4. LED Panel Driver

#### MiniLED Driver (`MiniLED_driver.v`)
Top-level LED control module that manages:
- Clock generation (25MHz, 1MHz via PLL)
- Data buffering via `ramflag_In`
- SRAM interface for frame buffering
- SPI7001 LED driver IC control

#### RAM Flag Input (`ramflag_In.v`)
Buffers and schedules LED brightness data:
- Receives 360-zone brightness values from algorithm
- Supports 4 display modes via `mode_selector`:
  - `2'b00`: Full backlight (unprocessed, maximum brightness)
  - `2'b01`: Half-screen comparison mode
  - `2'b10`: Zonal backlight with auto-brightness (I2C sensor)
  - `2'b11`: Zonal backlight mode
- Generates timing signals for SPI7001 driver

### 5. I2C Ambient Light Sensor (`i2c/`)

#### AP3216 Driver (`AP3216_driver.v` + `i2c_top.v`)
- Communicates with AP3216 ambient light sensor via I2C (400kHz)
- Reads 12-bit ambient light data
- Provides brightness adjustment for backlight control
- I2C registers:
  - `0x00`: System mode
  - `0x0C`: ALS data low byte
  - `0x0D`: ALS data high byte

## Key Interfaces

### Video Interface (LVDS)
| Signal | Direction | Description |
|--------|-----------|-------------|
| I_clkin_p/n | Input | LVDS clock input |
| I_din_p/n[3:0] | Input | 4-channel LVDS data input |
| O_clkout_p/n | Output | LVDS clock output |
| O_dout_p/n[3:0] | Output | 4-channel LVDS data output |

### LED Panel Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| LE | Output | Latch enable for LED driver |
| DCLK | Output | Data clock (12.5MHz) |
| SDI | Output | Serial data input |
| GCLK | Output | Global clock |
| scan1-4 | Output | Scan control lines |

### Control Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| I_clk | Input | System clock (50MHz) |
| I_rst_n | Input | Active-low reset |
| max_mode | Input | Select max algorithm |
| ave_mode | Input | Select average algorithm |
| cor_mode | Input | Select correction algorithm |
| led_mode[1:0] | Input | LED display mode selection |
| sda | Inout | I2C data (AP3216) |
| scl | Output | I2C clock (AP3216) |
| O_led[3:0] | Output | Mode indicator LEDs |

## Build and Development

### Development Environment
- **IDE**: Gowin Cloud Development Environment (Gowin IDE)
- **Version**: V1.9.10.02 or later
- **Target Device**: GW2A-55 series (GW2A-LV55PG484C8/I7)

### Project Files
1. Open `miniled.gprj` in Gowin IDE
2. The project includes all Verilog sources, constraints, and IP cores

### Constraints Files
- **`miniled.cst`**: Physical constraints defining pin locations and I/O standards
  - LVDS pins: LVDS25 standard, 2.5V bank
  - Control pins: LVCMOS25, pull-up enabled
  - Clock/Reset: LVCMOS15/LVCMOS25
  
- **`miniled.sdc`**: Timing constraints
  - `rx_sclk`: 70.2MHz (14.245ns period) - pixel clock
  - `I_clkin_p`: 70.2MHz - LVDS input clock
  - `I_clk`: 50MHz (20ns period) - system clock
  - `scl`: 100kHz I2C clock
  - Clock groups defined for exclusive clock domains

### Configuration Options

#### LVDS RX Configuration (`lvds_7to1_rx_defines.v`)
```verilog
`define MANUAL_PHASE              // Manual phase alignment
`define RX_USE_RPLL               // Use rPLL for clock
`define RX_ONE_CHANNEL            // Single LVDS channel
`define RX_VESA                   // VESA color mapping
`define RX_RGB888                 // 24-bit color depth
`define RX_CLK_PATTERN_1100011    // Clock pattern for alignment
`define RX_USE_CLKDIV_3_5         // 3.5× clock divider
```

#### LVDS TX Configuration (`lvds_7to1_tx_defines.v`)
```verilog
`define USE_TLVDS_OBUF            // True LVDS output buffer
`define TX_USE_RPLL               // Use rPLL for serial clock
`define TX_ONE_CHANNEL            // Single channel output
`define TX_VESA                   // VESA color mapping
`define TX_RGB888                 // 24-bit color depth
```

## Testing and Simulation

### Simulation Files
- `SPI7001_sim.v`: Simulation model for SPI7001 LED driver
- `sram_top_gowin_top_sim.v`: SRAM simulation model

### Test Points
- LED indicators (`O_led[3:0]`) show current `led_mode`
- Mode selection pins allow runtime algorithm switching

## Development Guidelines

### Code Style
1. **File Header**: Each file includes ASCII art header with:
   - Code name
   - Description
   - Version history table (Version | Author | Date | Mod.)

2. **Naming Conventions**:
   - Module names: descriptive, lowercase with underscores
   - Port names: `I_` prefix for inputs, `O_` prefix for outputs
   - Clock signals: `*_clk`, `sclk`, `dclk`
   - Active-low signals: `*_n` suffix (e.g., `I_rst_n`)

3. **Comments**: Mixed Chinese and English, primarily Chinese for algorithm descriptions

### IP Cores
The project uses Gowin primitive IP cores:
- **rPLL**: Reconfigurable PLL for clock generation
- **OVIDEO**: Output video serializer for LVDS TX
- **IDDR**: Input DDR for LVDS RX
- **SRAM**: Internal block RAM for LED data buffering

### Clock Domains
1. **I_clk**: 50MHz system clock (main control logic)
2. **rx_sclk**: ~70MHz pixel clock (from LVDS RX, video processing)
3. **clk25M**: 25MHz (LED driver clock)
4. **clk1M**: 1MHz (SPI7001 low-speed control)
5. **scl**: 400kHz I2C clock

## Notes

- The SPI7001 driver IP (`SPI7001_gowin.vp`) is encrypted and can only be used in Gowin tools
- Timing constraints are critical for LVDS interfaces - ensure proper constraints for synthesis
- The project is designed specifically for the Gowin MiniLED development kit hardware
- Ambient light sensing requires AP3216 sensor connected to I2C pins
