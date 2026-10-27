# NUCLEO-F413ZH UART starter

Open `MDK-ARM/nucleo_f413zh_uart.uvprojx` with Keil uVision 5.
The project targets STM32F413ZH and uses ARM Compiler 5.06 update 7,
HAL from STM32CubeF4 1.28.3, 1.5 MiB Flash and 320 KiB SRAM.
No external firmware repository paths are required to compile.

No board has been programmed or hardware-tested by this package's author.

The project has been rebuilt with the installed Keil ARM Compiler 5.06
update 7: 0 errors, 0 warnings, Code 7248 B, RO-data 528 B, RW-data 24 B,
ZI-data 1168 B. A prebuilt Intel HEX is under `firmware/`.
Set Options for Target -> Debug -> ST-Link Debugger, Settings -> Port =
SWD before programming. Use the matching ST-LINK entry in Utilities and
the STM32F4xx 1536 KiB Flash algorithm if it is not selected automatically.
Selecting a debugger is not a hardware connection test.

## Connections

- NUCLEO D1 / CN10-14 / PG14 / USART6_TX -> Basys 3 JA1 / RX.
- NUCLEO D0 / CN10-16 / PG9 / USART6_RX <- Basys 3 JA2 / TX.
- NUCLEO GND / CN10-22 <-> Basys 3 JA5 / GND.
- Power each board through its own programming USB. Do not connect the
  boards' 3V3 or 5V pins together. Signal level is 3.3 V UART, not RS-232.

## Configuration reproduced in CubeMX

Create a new MCU project for STM32F413ZHTx, Toolchain MDK-ARM V5.
Use HSI 16 MHz as SYSCLK, PLL disabled, AHB /1, APB1 /1, APB2 /1.
SYS Debug = Serial Wire; HAL timebase = SysTick.
Enable USART6 Asynchronous, TX PG14, RX PG9, AF8; 115200, 8 data bits,
1 stop bit, no parity, no flow control, oversampling 16.
Enable USART3 Asynchronous, TX PD8, RX PD9, AF7, same UART parameters.
Set PB0, PB7 and PB14 to GPIO Output Push Pull, initially Low.
No UART interrupts, DMA or RTOS are used in this first demonstration.
Generate peripheral initialization in separate `.c/.h` pairs.

For a CubeMX-generated project, add `board_link.c` to a source group and
`board_link.h` to Core/Inc. Add `#include "board_link.h"` in the USER CODE
Includes block, call `BoardLink_Init()` in USER CODE BEGIN 2, then call
`BoardLink_Task()` inside the USER CODE portion of the while loop.
Keep CubeMX-generated `gpio.c`, `usart.c`, MSP and interrupt files; do not
add this package's equivalents on top of them, or duplicate definitions
will occur. Ensure `huart3` and `huart6` are generated.
This package does not include an unverified hand-written .ioc file.

## Observable test

Connect the NUCLEO's CN1 ST-LINK USB to the computer. Open the ST-LINK
virtual COM port at 115200 8N1, no flow control, ASCII display.
Every 500 ms the board sends `A5 seq data xor` on USART6. `data = seq`.
The expected FPGA reply is `5A seq data xor`. XOR includes the preceding
three bytes. The code verifies header, sequence, data and checksum.

- `PASS seq=... data=0x...`: valid round trip; green LD1 toggles, red LD3 off.
- `TIMEOUT ...`: no complete response within 100 ms; red LD3 on.
- `BAD ...`: incomplete/error response or bytes failed validation.
- Blue LD2/PB7 toggles each transaction attempt, including on failures.

Green LD1 normally uses PB0; a modified board can route it to PA5 via
solder bridges. The serial PASS message is the definitive test result.

The main program is intentionally simple and polling-based for initial
wiring verification. A later game implementation should use interrupt or
DMA reception and a framed message protocol with appropriate checks.

## Provenance

ST HAL, CMSIS and the device startup are copied from locally installed
STM32CubeF4 1.28.3. Their original license files are retained under Drivers,
and the original firmware package license is at `Package_license.md`.
The app and Keil project configuration are provided as editable sources.
