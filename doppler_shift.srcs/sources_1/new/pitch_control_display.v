`timescale 1ns / 1ps
`default_nettype none

// Up/down buttons set pitch_pct, shown on the seven segment display
module pitch_control_display #(
    parameter integer CLK_HZ = 22591000
) (
    input  wire clk,
    input  wire resetn,

    input  wire btn_up,
    input  wire btn_dn,

    output reg signed [7:0] pitch_pct = 8'sd0,

    output reg [6:0] seg = 7'b1111111,
    output reg [3:0] an  = 4'b1111
);

    localparam signed [7:0] PCT_MIN = -8'sd50;
    localparam signed [7:0] PCT_MAX =  8'sd99;

    localparam integer SAMPLE_DIV = CLK_HZ / 200;  // 5 ms debounce tick
    localparam integer HOLD_TICKS = 100;           // 500 ms before auto repeat
    localparam integer RPT_TICKS  = 20;            // 100 ms between repeats

    reg [$clog2(SAMPLE_DIV)-1:0] samp_cnt = 0;
    wire tick = (samp_cnt == SAMPLE_DIV - 1);

    reg up_s = 1'b0, up_q = 1'b0;
    reg dn_s = 1'b0, dn_q = 1'b0;
    reg [7:0] hold_cnt = 8'd0;

    wire up_press = tick && up_s && !up_q;
    wire dn_press = tick && dn_s && !dn_q;
    wire held     = up_s || dn_s;

    wire repeat_now = tick && held && (hold_cnt >= HOLD_TICKS) &&
                      (((hold_cnt - HOLD_TICKS) % RPT_TICKS) == 0);

    always @(posedge clk) begin
        if (!resetn) begin
            samp_cnt  <= 0;
            up_s      <= 1'b0;  up_q <= 1'b0;
            dn_s      <= 1'b0;  dn_q <= 1'b0;
            hold_cnt  <= 8'd0;
            pitch_pct <= 8'sd0;
        end else begin
            samp_cnt <= tick ? 0 : samp_cnt + 1'b1;

            if (tick) begin
                up_q <= up_s;   up_s <= btn_up;
                dn_q <= dn_s;   dn_s <= btn_dn;

                if (held) begin
                    if (hold_cnt != 8'd255)
                        hold_cnt <= hold_cnt + 1'b1;
                end else begin
                    hold_cnt <= 8'd0;
                end
            end

            // both buttons resets to 0
            if (up_press && dn_press) begin
                pitch_pct <= 8'sd0;
            end else if ((up_press || (repeat_now && up_s)) && pitch_pct < PCT_MAX) begin
                pitch_pct <= pitch_pct + 8'sd1;
            end else if ((dn_press || (repeat_now && dn_s)) && pitch_pct > PCT_MIN) begin
                pitch_pct <= pitch_pct - 8'sd1;
            end
        end
    end

    // binary to decimal digits of the magnitude, sign goes on the left digit
    wire [7:0] magnitude = pitch_pct[7] ? -pitch_pct : pitch_pct;
    reg  [7:0] work;
    reg  [3:0] huns, tens, ones;

    integer j;
    always @(*) begin
        work = magnitude;
        huns = 4'd0;
        if (work >= 8'd100) begin
            huns = 4'd1;
            work = work - 8'd100;
        end
        tens = 4'd0;
        for (j = 0; j < 10; j = j + 1)
            if (work >= 8'd10) begin
                work = work - 8'd10;
                tens = tens + 4'd1;
            end
        ones = work[3:0];
    end

    localparam [6:0] BLANK = 7'b1111111;
    localparam [6:0] MINUS = 7'b0111111;

    function [6:0] seg7;
        input [3:0] d;
        begin
            case (d)
                4'd0: seg7 = 7'b1000000;
                4'd1: seg7 = 7'b1111001;
                4'd2: seg7 = 7'b0100100;
                4'd3: seg7 = 7'b0110000;
                4'd4: seg7 = 7'b0011001;
                4'd5: seg7 = 7'b0010010;
                4'd6: seg7 = 7'b0000010;
                4'd7: seg7 = 7'b1111000;
                4'd8: seg7 = 7'b0000000;
                4'd9: seg7 = 7'b0010000;
                default: seg7 = BLANK;
            endcase
        end
    endfunction

    // multiplex the four digits
    reg [16:0] refresh = 17'd0;
    always @(posedge clk)
        refresh <= refresh + 1'b1;

    wire [1:0] digit = refresh[16:15];

    always @(posedge clk) begin
        case (digit)
            2'd0: begin an <= 4'b1110; seg <= seg7(ones); end
            2'd1: begin an <= 4'b1101; seg <= seg7(tens); end
            2'd2: begin an <= 4'b1011; seg <= seg7(huns); end
            2'd3: begin an <= 4'b0111; seg <= pitch_pct[7] ? MINUS : BLANK; end
        endcase
    end

endmodule

`default_nettype wire
