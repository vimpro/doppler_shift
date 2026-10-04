@echo off
rem Runs tb_latency in xsim from the command line
rem Usage: run_latency_sim.bat [pitch_percent] [frames]
setlocal
set PITCH=%~1
if "%PITCH%"=="" set PITCH=12
set FRAMES=%~2
if "%FRAMES%"=="" set FRAMES=500

set XBIN=C:\Xilinx\2025.1\Vivado\bin
set ROOT=%~dp0
set SRC=%ROOT%doppler_shift.srcs\sources_1\new
set IP=%ROOT%doppler_shift.gen\sources_1\ip\clk_wiz_0
set OUT=%ROOT%doppler_shift.sim\latency_cli

if not exist "%OUT%" mkdir "%OUT%"
pushd "%OUT%"

call "%XBIN%\xvlog.bat" "%IP%\clk_wiz_0_clk_wiz.v" "%IP%\clk_wiz_0.v" ^
    "%SRC%\axis_i2s2.v" "%SRC%\axis_pitch_shifter.v" "%SRC%\pitch_control_display.v" "%SRC%\top.v" ^
    "%ROOT%doppler_shift.srcs\sim_1\new\tb_latency.v" ^
    "%XBIN%\..\data\verilog\src\glbl.v" > compile.log || goto fail
call "%XBIN%\xelab.bat" tb_latency glbl -L unisims_ver -s lat ^
    -generic_top "PITCH=%PITCH%" -generic_top "FRAMES=%FRAMES%" > elab.log || goto fail
call "%XBIN%\xsim.bat" lat -R

popd
exit /b 0

:fail
echo Build failed, see logs in %OUT%
popd
exit /b 1
