`timescale 1ns / 1ps
`default_nettype none

// FPGA-side latency of the doppler shift design, codec delay not included
// Part 1 sends a marker sample in bypass and times it from line in to line out
// Part 2 forces a pitch and tracks the delay of the two read taps
module tb_latency;
    parameter integer PITCH  = 12;   // percent used in part 2
    parameter integer FRAMES = 500;  // frames watched in part 2

    localparam [23:0] MARKER = 24'h3C3C3C;

    reg clk = 1'b0, reset = 1'b1, rx_data = 1'b0;
    always #5 clk = ~clk;  // 100 MHz board clock

    wire tx_mclk, tx_lrck, tx_sclk, tx_data, rx_mclk, rx_lrck, rx_sclk;
    wire [6:0] seg;
    wire [3:0] an;

    top dut (
        .clk(clk), .reset(reset),
        .tx_mclk(tx_mclk), .tx_lrck(tx_lrck), .tx_sclk(tx_sclk), .tx_data(tx_data),
        .rx_mclk(rx_mclk), .rx_lrck(rx_lrck), .rx_sclk(rx_sclk), .rx_data(rx_data),
        .btn_up(1'b0), .btn_dn(1'b0),
        .seg(seg), .an(an)
    );

    // the i2s2 frame counter tells us which bit slot is on the wire
    wire       axis_clk = dut.axis_clk;
    wire [8:0] count    = dut.m_i2s2.count;
    wire [4:0] slot     = count[7:3];
    wire       in_slot  = (slot >= 1) && (slot <= 24);

    real    t_frame = 0.0, frame_ns = 0.0, t_slot1 = 0.0;
    real    t_in_first = 0.0, t_in_last = 0.0, t_out_first = 0.0;
    integer cycle = 0, cyc_rx = 0, cyc_tx = 0;
    reg     send = 1'b0, sent = 1'b0, got = 1'b0, waiting_tx = 1'b0;
    reg     [23:0] rx_word = 24'd0, tx_shift = 24'd0;

    always @(posedge axis_clk) cycle <= cycle + 1;

    // line in: marker on the left channel of one frame, silence otherwise
    always @(posedge axis_clk) begin
        #1;
        if (count == 9'd0) begin
            if (t_frame > 0.0) frame_ns = $realtime - t_frame;
            t_frame = $realtime;
            rx_word = (send && !sent) ? MARKER : 24'd0;
            if (send && !sent) sent = 1'b1;
        end
        if (count == 9'd8) begin
            t_slot1 = $realtime;
            if (rx_word == MARKER) t_in_first = $realtime;
        end
        if (count == 9'd200 && rx_word == MARKER) t_in_last = $realtime;
        rx_data = (!count[8] && in_slot) ? rx_word[24 - slot] : 1'b0;
    end

    // line out: decode left words at the same point the receiver samples
    always @(posedge axis_clk) begin
        if (!count[8] && in_slot && count[2:0] == 3'd3) begin
            tx_shift = {tx_shift[22:0], tx_data};
            if (slot == 5'd24 && tx_shift == MARKER && !got) begin
                got         = 1'b1;
                t_out_first = t_slot1;
            end
        end
    end

    // shifter processing time, right word accepted to first output word valid
    always @(posedge axis_clk) begin
        if (sent && !waiting_tx && cyc_rx == 0 && dut.rx_valid && dut.rx_ready && dut.rx_last) begin
            cyc_rx     = cycle;
            waiting_tx = 1'b1;
        end else if (waiting_tx && dut.tx_valid) begin
            cyc_tx     = cycle;
            waiting_tx = 1'b0;
        end
    end

    // part 2 helpers
    real d_a, d_b, g_a, g_b, w, w_min, w_max, w_sum;
    integer n;

    function real to_samples(input [31:0] d);
        to_samples = d / 1048576.0;  // 2**FRAC_BITS
    endfunction

    initial begin
        #2000 reset = 1'b0;  // let the MMCM lock first
        repeat (4) @(posedge axis_clk);
        wait (count == 9'd100);
        send = 1'b1;
        wait (got);
        #1;

        $display("");
        $display("=== Part 1: bypass (pitch 0) ===");
        $display("axis_clk period       %0.2f ns, sample rate %0.1f Hz", frame_ns / 512.0, 1.0e9 / frame_ns);
        $display("first bit in to out   %0.2f us (%0.2f frames)", (t_out_first - t_in_first) / 1000.0, (t_out_first - t_in_first) / frame_ns);
        $display("last bit in to first out %0.2f us", (t_out_first - t_in_last) / 1000.0);
        $display("pitch shifter         %0d axis_clk cycles (%0.3f us)", cyc_tx - cyc_rx, (cyc_tx - cyc_rx) * frame_ns / 512.0 / 1000.0);

        force dut.pitch_pct = PITCH;
        w_min = 1.0e9; w_max = 0.0; w_sum = 0.0;
        for (n = 0; n < FRAMES; n = n + 1) begin
            @(posedge axis_clk);
            while (dut.m_pitch.state != 4'd5) @(posedge axis_clk);  // S_MIX
            d_a = to_samples(dut.m_pitch.delay);
            d_b = to_samples(dut.m_pitch.delay_b);
            g_a = dut.m_pitch.ga_q;
            g_b = dut.m_pitch.gb_q;
            w   = (g_a * d_a + g_b * d_b) / (g_a + g_b);
            if (w < w_min) w_min = w;
            if (w > w_max) w_max = w;
            w_sum = w_sum + w;
            if (n % (FRAMES / 5) == 0)
                $display("  frame %4d  tap A %7.1f  tap B %7.1f  gain A %0.2f  -> %0.1f samples",
                         n, d_a, d_b, g_a / (g_a + g_b), w);
        end

        $display("");
        $display("=== Part 2: pitch %0d%% over %0d frames ===", PITCH, FRAMES);
        $display("gain weighted tap delay  min %0.1f  max %0.1f  avg %0.1f samples", w_min, w_max, w_sum / FRAMES);
        $display("on top of bypass, about %0.2f ms", (w_sum / FRAMES) * frame_ns / 1.0e6);
        $display("");
        $finish;
    end

    initial begin
        #5_000_000;
        if (!got) begin
            $display("TIMEOUT, marker never came out");
            $finish;
        end
    end
endmodule

`default_nettype wire
