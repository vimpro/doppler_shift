# Doppler Shift

This is a real time audio pitch shifter built on a Basys3 FPGA. The audio input signal comes in through the Digilent Pmod I2S2, gets shifted up or down while playing at normal speed, and comes back out the line out jack from the same Pmod header. The current percent pitch shift is shown on the seven-segment display.

## Demo

https://github.com/user-attachments/assets/b49d8a51-f050-4d62-912f-3ded72625914

## Hardware

- Digilent Basys 3 (Vivado part number `xc7a35tcpg236-1`)
- Digilent Pmod I2S2 on header JA

## Code explanation

- `axis_i2s2.v` uses the I2S protocol to read 24 bit audio samples (in stereo) from the line in/out Pmod, and then writes that to an AXI Stream at 44.1 kHz. This is not my own code, it is from Digilent.

- `axis_pitch_shifter.v` writes every sample into a circular buffer, one for each left and right track in stereo. There are then 2 taps that read from the buffer which are 180 degrees phase apart, and we do a linear crossfade between the two each time one hits the end of the buffer and has to loop back. That way, each of them can read faster or slower than the actual signal, and we hide the fact that the speed is mismatched by fading between them.

- `pitch_control_display.v` debounces the buttons, adds auto-repeat while a button is held, and uses multiplexing to show the the pitch % on the 7 seg display

- I am using the default `clk_wiz_0` IP to generate 22.591 MHz for the audio from the 100 MHz board clock

## Latency

Measured in simulation with `tb_latency.v`:

| Mode | Latency |
|---|---|
| 0% (bypass) | 1 sample, about 23 µs |
| Shifting | about 46 ms (half the buffer, 2048 samples) |

## Simulation

I also have a CLI testbench to test the latency. You can run it using the following command. The arguments are the pitch percent and how many frames to watch:

```
run_latency_sim.bat 12 500
```

Or in Vivado, do Run Behavioral Simulation and then Run All.
