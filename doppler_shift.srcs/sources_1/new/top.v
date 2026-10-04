`timescale 1ns / 1ps
`default_nettype none

module top (
    input  wire        clk,
    input  wire        reset,

    output wire        tx_mclk,
    output wire        tx_lrck,
    output wire        tx_sclk,
    output wire        tx_data,
    output wire        rx_mclk,
    output wire        rx_lrck,
    output wire        rx_sclk,
    input  wire        rx_data,

    input  wire        btn_up,
    input  wire        btn_dn,
    output wire [6:0]  seg,
    output wire [3:0]  an
);
    localparam integer AXIS_CLK_HZ = 22591000;

    wire axis_clk;
    wire resetn = ~reset;

    wire [23:0] tx_data_w, rx_data_w;
    wire [31:0] rx_word;
    wire        tx_valid, tx_ready, tx_last;
    wire        rx_valid, rx_ready, rx_last;
    wire signed [7:0] pitch_pct;

    // i2s2 carries 24-bit audio in the low bits of a 32-bit word
    assign rx_data_w = rx_word[23:0];

    clk_wiz_0 m_clk (
        .clk_in1(clk),
        .axis_clk(axis_clk)
    );

    axis_i2s2 m_i2s2 (
        .axis_clk(axis_clk),
        .axis_resetn(resetn),

        .tx_axis_s_data({8'd0, tx_data_w}),
        .tx_axis_s_valid(tx_valid),
        .tx_axis_s_ready(tx_ready),
        .tx_axis_s_last(tx_last),

        .rx_axis_m_data(rx_word),
        .rx_axis_m_valid(rx_valid),
        .rx_axis_m_ready(rx_ready),
        .rx_axis_m_last(rx_last),

        .tx_mclk(tx_mclk),
        .tx_lrck(tx_lrck),
        .tx_sclk(tx_sclk),
        .tx_sdout(tx_data),
        .rx_mclk(rx_mclk),
        .rx_lrck(rx_lrck),
        .rx_sclk(rx_sclk),
        .rx_sdin(rx_data)
    );

    pitch_control_display #(.CLK_HZ(AXIS_CLK_HZ)) m_ctrl (
        .clk(axis_clk),
        .resetn(resetn),
        .btn_up(btn_up),
        .btn_dn(btn_dn),
        .pitch_pct(pitch_pct),
        .seg(seg),
        .an(an)
    );

    axis_pitch_shifter m_pitch (
        .clk(axis_clk),
        .resetn(resetn),
        .pitch_pct(pitch_pct),

        .s_axis_data(rx_data_w),
        .s_axis_valid(rx_valid),
        .s_axis_ready(rx_ready),
        .s_axis_last(rx_last),

        .m_axis_data(tx_data_w),
        .m_axis_valid(tx_valid),
        .m_axis_ready(tx_ready),
        .m_axis_last(tx_last)
    );
endmodule

`default_nettype wire
