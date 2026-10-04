# Doppler Shift

Real-time audio pitch shifter on an FPGA. Audio goes into a Basys 3 through a Pmod I2S2, gets shifted up or down while playing at normal speed, and comes back out the line out jack. The current shift is shown on the seven-segment display.

## Demo

<!--
To add the video, edit this README on github.com and drag an .mp4 (under 10 MB) onto
this spot. GitHub uploads it and pastes a link that plays inline. Replace the line below with it.

For a YouTube video, use a clickable thumbnail instead:
[![Demo](https://img.youtube.com/vi/VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=VIDEO_ID)
-->

_Video coming soon_

## Hardware

- Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`)
- Digilent Pmod I2S2 on header **JA**
- Audio source into the I2S2 line in, speakers or headphones on the line out

| Control | Action |
|---|---|
| BTNU | Pitch up 1% (hold to repeat) |
| BTND | Pitch down 1% (hold to repeat) |
| BTNU + BTND | Reset to 0% |
| BTNC | Reset the design |

The range is -50% (an octave down) to +99% (almost an octave up). At 0% the audio passes through untouched.

## How it works

```
line in -> axis_i2s2 -> axis_pitch_shifter -> axis_i2s2 -> line out
                               ^
          buttons -> pitch_control_display -> 7-seg display
```

- **`axis_i2s2.v`** talks I2S to the codec and turns 24-bit stereo samples into an AXI-Stream at 44.1 kHz. It's from Digilent's Pmod I2S2 demo.
- **`axis_pitch_shifter.v`** writes every sample into a 4096-sample circular buffer, one buffer for each channel. Samples are read back at a different rate than they're written, which changes the pitch without changing the speed.
  - The reader keeps a fractional delay that drifts by `pitch%` of a sample each frame. Linear interpolation between neighbouring samples handles the fraction.
  - When a read point drifts past the write point, it jumps to the other end of the buffer, which would click. To hide that, there are two read taps half a buffer apart, crossfaded with triangle-shaped gains so each tap is silent at the moment it jumps.
- **`pitch_control_display.v`** debounces the buttons, adds auto-repeat while a button is held, and drives the display.
- **`clk_wiz_0`** makes the 22.591 MHz audio clock from the 100 MHz board clock.

## Latency

Measured in simulation with `tb_latency.v`, not counting the codec's own delay:

| Mode | Latency |
|---|---|
| 0% (bypass) | 1 sample, about 23 µs |
| Shifting | about 46 ms (half the buffer, 2048 samples) |

## Building

1. Open `doppler_shift.xpr` in Vivado 2025.1. Vivado regenerates the clock IP and build folders.
2. Run **Generate Bitstream** and program the board with Hardware Manager.
3. To boot from flash, generate a `.mcs` for the onboard QSPI flash (SPIx4) and program it as configuration memory.

## Simulation

Run the latency testbench from the command line. The arguments are the pitch percent and how many frames to watch:

```
run_latency_sim.bat 12 500
```

Or in Vivado, choose **Run Behavioral Simulation** and then **Run All**.

## Layout

```
doppler_shift.xpr                 Vivado project
doppler_shift.srcs/
  sources_1/new/                  Verilog sources
  sources_1/ip/clk_wiz_0/         clock wizard config
  constrs_1/new/Basys3.xdc        pin constraints
  sim_1/new/tb_latency.v          latency testbench
run_latency_sim.bat               command line simulation
```
