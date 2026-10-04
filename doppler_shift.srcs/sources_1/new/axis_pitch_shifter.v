`timescale 1ns / 1ps
`default_nettype none

// Delay-line pitch shifter with two crossfaded taps half a buffer apart
// Stereo AXIS in and out, left then right with TLAST on right
module axis_pitch_shifter #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_BITS  = 12
) (
    input  wire clk,
    input  wire resetn,

    input  wire signed [7:0] pitch_pct,  // 0 bypasses

    input  wire [DATA_WIDTH-1:0] s_axis_data,
    input  wire                  s_axis_valid,
    output reg                   s_axis_ready = 1'b1,
    input  wire                  s_axis_last,

    output reg  [DATA_WIDTH-1:0] m_axis_data  = {DATA_WIDTH{1'b0}},
    output reg                   m_axis_valid = 1'b0,
    input  wire                  m_axis_ready,
    output reg                   m_axis_last  = 1'b0
);

    // delay is a 32-bit fixed point with ADDR_BITS integer bits so it wraps at the buffer length
    localparam integer BUF_LEN   = 1 << ADDR_BITS;
    localparam integer FRAC_BITS = 32 - ADDR_BITS;
    localparam integer GAIN_BITS = 19;
    localparam signed [31:0] PCT_STEP = (1 << FRAC_BITS) / 100;

    // left and right share an address so one read returns both
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] buf_l [0:BUF_LEN-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] buf_r [0:BUF_LEN-1];

    reg [ADDR_BITS-1:0]  wr_ptr = {ADDR_BITS{1'b0}};
    reg [ADDR_BITS-1:0]  rd_addr;
    reg [DATA_WIDTH-1:0] rd_l, rd_r;
    reg                  mem_we = 1'b0;
    reg [DATA_WIDTH-1:0] wr_l, wr_r;

    always @(posedge clk) begin
        if (mem_we) begin
            buf_l[wr_ptr] <= wr_l;
            buf_r[wr_ptr] <= wr_r;
        end
        rd_l <= buf_l[rd_addr];
        rd_r <= buf_r[rd_addr];
    end

    // higher pitch means a shrinking delay
    reg  [31:0] delay = 32'd0;
    wire signed [31:0] delay_step = -($signed(pitch_pct) * PCT_STEP);

    // tap B is tap A with the MSB flipped, half a buffer away
    wire [31:0] delay_b = {~delay[31], delay[30:0]};

    wire [ADDR_BITS-1:0] int_a  = delay[31:FRAC_BITS];
    wire [ADDR_BITS-1:0] int_b  = delay_b[31:FRAC_BITS];
    wire [FRAC_BITS-1:0] frac_a = delay[FRAC_BITS-1:0];
    wire [FRAC_BITS-1:0] frac_b = delay_b[FRAC_BITS-1:0];

    // triangular crossfade over the full delay, tap B gain is the complement of tap A
    wire [GAIN_BITS-1:0] gain_a = delay[31] ? ~delay[30 -: GAIN_BITS]
                                            :  delay[30 -: GAIN_BITS];
    wire [GAIN_BITS-1:0] gain_b = ~gain_a;

    reg [DATA_WIDTH-1:0] a0_l, a1_l, b0_l, b1_l;
    reg [DATA_WIDTH-1:0] a0_r, a1_r, b0_r, b1_r;
    reg [FRAC_BITS-1:0]  fa_q, fb_q;
    reg [GAIN_BITS-1:0]  ga_q, gb_q;

    reg signed [DATA_WIDTH:0] ia_l, ib_l, ia_r, ib_r;
    reg [DATA_WIDTH-1:0]      out_l, out_r;
    reg [DATA_WIDTH-1:0]      raw_l, raw_r;

    localparam [3:0] S_GET_L  = 4'd0,
                     S_GET_R  = 4'd1,
                     S_WRITE  = 4'd2,
                     S_READ   = 4'd3,
                     S_INTERP = 4'd4,
                     S_MIX    = 4'd5,
                     S_OUT_L  = 4'd6,
                     S_OUT_R  = 4'd7;

    reg [3:0] state  = S_GET_L;
    reg [2:0] rd_cnt = 3'd0;

    always @(*) begin
        case (rd_cnt)
            3'd0:    rd_addr = wr_ptr - int_a;
            3'd1:    rd_addr = wr_ptr - int_a - 1'b1;
            3'd2:    rd_addr = wr_ptr - int_b;
            3'd3:    rd_addr = wr_ptr - int_b - 1'b1;
            default: rd_addr = wr_ptr;
        endcase
    end

    function signed [DATA_WIDTH:0] lerp;
        input [DATA_WIDTH-1:0] near;
        input [DATA_WIDTH-1:0] far;
        input [FRAC_BITS-1:0]  f;
        reg signed [DATA_WIDTH:0]           d;
        reg signed [DATA_WIDTH+FRAC_BITS:0] p;
        begin
            d    = $signed({far[DATA_WIDTH-1], far}) - $signed({near[DATA_WIDTH-1], near});
            p    = d * $signed({1'b0, f});
            lerp = $signed({near[DATA_WIDTH-1], near}) + (p >>> FRAC_BITS);
        end
    endfunction

    wire signed [DATA_WIDTH+GAIN_BITS+1:0] mix_l =
        (ia_l * $signed({1'b0, ga_q})) + (ib_l * $signed({1'b0, gb_q}));
    wire signed [DATA_WIDTH+GAIN_BITS+1:0] mix_r =
        (ia_r * $signed({1'b0, ga_q})) + (ib_r * $signed({1'b0, gb_q}));

    // bypass at 0 to avoid comb filtering from a static delay
    wire bypass = (pitch_pct == 8'sd0);

    always @(posedge clk) begin
        if (!resetn) begin
            state        <= S_GET_L;
            s_axis_ready <= 1'b1;
            m_axis_valid <= 1'b0;
            m_axis_last  <= 1'b0;
            wr_ptr       <= {ADDR_BITS{1'b0}};
            delay        <= 32'd0;
            mem_we       <= 1'b0;
            rd_cnt       <= 3'd0;
        end else begin
            mem_we <= 1'b0;

            case (state)
                S_GET_L: begin
                    s_axis_ready <= 1'b1;
                    m_axis_valid <= 1'b0;
                    if (s_axis_valid && s_axis_ready && !s_axis_last) begin
                        raw_l <= s_axis_data;
                        wr_l  <= s_axis_data;
                        state <= S_GET_R;
                    end
                end

                S_GET_R: begin
                    if (s_axis_valid && s_axis_ready && s_axis_last) begin
                        raw_r        <= s_axis_data;
                        wr_r         <= s_axis_data;
                        s_axis_ready <= 1'b0;
                        mem_we       <= 1'b1;
                        state        <= S_WRITE;
                    end
                end

                S_WRITE: begin
                    delay  <= delay + delay_step;
                    rd_cnt <= 3'd0;
                    state  <= S_READ;
                end

                // one read per cycle, data lands a cycle later
                S_READ: begin
                    rd_cnt <= rd_cnt + 1'b1;
                    case (rd_cnt)
                        3'd0: begin fa_q <= frac_a; fb_q <= frac_b;
                                    ga_q <= gain_a; gb_q <= gain_b; end
                        3'd1: begin a0_l <= rd_l; a0_r <= rd_r; end
                        3'd2: begin a1_l <= rd_l; a1_r <= rd_r; end
                        3'd3: begin b0_l <= rd_l; b0_r <= rd_r; end
                        3'd4: begin b1_l <= rd_l; b1_r <= rd_r;
                                    state <= S_INTERP; end
                        default: ;
                    endcase
                end

                S_INTERP: begin
                    ia_l  <= lerp(a0_l, a1_l, fa_q);
                    ib_l  <= lerp(b0_l, b1_l, fb_q);
                    ia_r  <= lerp(a0_r, a1_r, fa_q);
                    ib_r  <= lerp(b0_r, b1_r, fb_q);
                    state <= S_MIX;
                end

                S_MIX: begin
                    out_l  <= bypass ? raw_l : mix_l[DATA_WIDTH+GAIN_BITS-1 -: DATA_WIDTH];
                    out_r  <= bypass ? raw_r : mix_r[DATA_WIDTH+GAIN_BITS-1 -: DATA_WIDTH];
                    wr_ptr <= wr_ptr + 1'b1;
                    state  <= S_OUT_L;
                end

                S_OUT_L: begin
                    m_axis_data  <= out_l;
                    m_axis_last  <= 1'b0;
                    m_axis_valid <= 1'b1;
                    if (m_axis_valid && m_axis_ready) begin
                        m_axis_data <= out_r;
                        m_axis_last <= 1'b1;
                        state       <= S_OUT_R;
                    end
                end

                S_OUT_R: begin
                    if (m_axis_valid && m_axis_ready) begin
                        m_axis_valid <= 1'b0;
                        m_axis_last  <= 1'b0;
                        s_axis_ready <= 1'b1;
                        state        <= S_GET_L;
                    end
                end

                default: state <= S_GET_L;
            endcase
        end
    end

endmodule

`default_nettype wire
