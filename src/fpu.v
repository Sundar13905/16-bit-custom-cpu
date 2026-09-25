`timescale 1ns/1ps

module fpu (
    input  wire        enable,
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [3:0]  opcode,
    output reg  [15:0] result
);

    // ==========================================================
    // Opcode
    // ==========================================================
    // 0000 = FADD
    // 0001 = FMUL
    // ==========================================================


    // ==========================================================
    // Shift right with sticky bit
    // ==========================================================
    function [13:0] shr_sticky;
        input [13:0] x;
        input integer sh;

        integer i;
        reg sticky;
        reg [13:0] tmp;

        begin
            if (sh <= 0) begin
                shr_sticky = x;
            end
            else if (sh >= 14) begin
                if (x != 0)
                    shr_sticky = 14'b00000000000001;
                else
                    shr_sticky = 14'b0;
            end
            else begin
                tmp = x >> sh;
                sticky = 1'b0;

                for (i = 0; i < sh; i = i + 1)
                    sticky = sticky | x[i];

                tmp[0] = tmp[0] | sticky;

                shr_sticky = tmp;
            end
        end
    endfunction


    // ==========================================================
    // IEEE-754 Half Precision Addition
    // ==========================================================
    function [15:0] fp16_add;
        input [15:0] x;
        input [15:0] y;

        reg sx, sy, sr;

        reg [4:0] exf, eyf;
        reg [9:0] fxf, fyf;

        reg [10:0] sigx, sigy;

        reg [13:0] extx, exty, extr;
        reg [14:0] sum_ext;

        reg [11:0] sig_r;
        reg [4:0] exp_field;

        reg guard_bit;
        reg round_bit;
        reg sticky_bit;
        reg round_up;

        reg nan_x, nan_y;
        reg inf_x, inf_y;

        integer ex, ey, er;
        integer diff;

        begin

            // --------------------------------------------------
            // Decode
            // --------------------------------------------------
            sx  = x[15];
            sy  = y[15];

            exf = x[14:10];
            eyf = y[14:10];

            fxf = x[9:0];
            fyf = y[9:0];


            // --------------------------------------------------
            // Special values
            // --------------------------------------------------
            nan_x = (exf == 5'h1F) && (fxf != 0);
            nan_y = (eyf == 5'h1F) && (fyf != 0);

            inf_x = (exf == 5'h1F) && (fxf == 0);
            inf_y = (eyf == 5'h1F) && (fyf == 0);


            // NaN
            if (nan_x || nan_y) begin

                fp16_add = 16'h7E00;

            end

            // +Inf + -Inf = NaN
            else if (inf_x && inf_y && (sx != sy)) begin

                fp16_add = 16'h7E00;

            end

            // Infinity
            else if (inf_x) begin

                fp16_add = {sx, 5'h1F, 10'b0};

            end

            else if (inf_y) begin

                fp16_add = {sy, 5'h1F, 10'b0};

            end

            else begin

                // --------------------------------------------------
                // Decode operand X
                // --------------------------------------------------
                if (exf == 0) begin
                    ex   = -14;
                    sigx = {1'b0, fxf};
                end
                else begin
                    ex   = exf - 15;
                    sigx = {1'b1, fxf};
                end


                // --------------------------------------------------
                // Decode operand Y
                // --------------------------------------------------
                if (eyf == 0) begin
                    ey   = -14;
                    sigy = {1'b0, fyf};
                end
                else begin
                    ey   = eyf - 15;
                    sigy = {1'b1, fyf};
                end


                // --------------------------------------------------
                // Zero cases
                // --------------------------------------------------
                if ((sigx == 0) && (sigy == 0)) begin

                    if (sx && sy)
                        fp16_add = 16'h8000;
                    else
                        fp16_add = 16'h0000;

                end

                else if (sigx == 0) begin

                    fp16_add = y;

                end

                else if (sigy == 0) begin

                    fp16_add = x;

                end

                else begin

                    // --------------------------------------------------
                    // Align exponents
                    // --------------------------------------------------
                    if (ex > ey) begin

                        er   = ex;
                        diff = ex - ey;

                        extx = {sigx, 3'b000};
                        exty = shr_sticky({sigy, 3'b000}, diff);

                    end

                    else if (ey > ex) begin

                        er   = ey;
                        diff = ey - ex;

                        extx = shr_sticky({sigx, 3'b000}, diff);
                        exty = {sigy, 3'b000};

                    end

                    else begin

                        er   = ex;

                        extx = {sigx, 3'b000};
                        exty = {sigy, 3'b000};

                    end


                    // --------------------------------------------------
                    // Same sign -> addition
                    // --------------------------------------------------
                    if (sx == sy) begin

                        sum_ext = {1'b0, extx} +
                                  {1'b0, exty};

                        sr = sx;

                        // Carry from bit 13
                        if (sum_ext[14]) begin

                            extr = sum_ext[14:1];

                            // Preserve sticky information
                            extr[0] = sum_ext[1] |
                                      sum_ext[0];

                            er = er + 1;

                        end
                        else begin

                            extr = sum_ext[13:0];
                        end

                    end

                    // --------------------------------------------------
                    // Different signs -> subtraction
                    // --------------------------------------------------
                    else begin

                        if (extx >= exty) begin

                            extr = extx - exty;
                            sr   = sx;

                        end
                        else begin

                            extr = exty - extx;
                            sr   = sy;

                        end


                        // Normalize subtraction result
                        while ((extr[13] == 1'b0) &&
                               (er > -14) &&
                               (extr != 0)) begin

                            extr = extr << 1;
                            er   = er - 1;

                        end

                    end


                    // --------------------------------------------------
                    // Exact zero
                    // --------------------------------------------------
                    if (extr == 0) begin

                        fp16_add = 16'h0000;

                    end

                    else begin

                        // --------------------------------------------------
                        // Move result into subnormal range
                        // --------------------------------------------------
                        if (er < -14) begin

                            extr = shr_sticky(
                                extr,
                                -14 - er
                            );

                            er = -14;

                        end


                        // --------------------------------------------------
                        // Extract significand + GRS
                        // --------------------------------------------------
                        sig_r = {1'b0, extr[13:3]};

                        guard_bit  = extr[2];
                        round_bit  = extr[1];
                        sticky_bit = extr[0];


                        // --------------------------------------------------
                        // Round-to-nearest-even
                        // --------------------------------------------------
                        round_up =
                            guard_bit &&
                            (round_bit ||
                             sticky_bit ||
                             sig_r[0]);


                        if (round_up)
                            sig_r = sig_r + 1'b1;


                        // --------------------------------------------------
                        // Rounding overflow
                        // --------------------------------------------------
                        if (sig_r == 12'd2048) begin

                            sig_r = 12'd1024;
                            er = er + 1;

                        end


                        // --------------------------------------------------
                        // Overflow
                        // --------------------------------------------------
                        if (er > 15) begin

                            fp16_add =
                                {sr, 5'h1F, 10'b0};

                        end

                        // --------------------------------------------------
                        // Subnormal
                        // --------------------------------------------------
                        else if ((er == -14) &&
                                 (sig_r < 11'd1024)) begin

                            fp16_add =
                                {sr,
                                 5'b00000,
                                 sig_r[9:0]};

                        end

                        // --------------------------------------------------
                        // Normal
                        // --------------------------------------------------
                        else begin

                            exp_field = er + 15;

                            fp16_add =
                                {sr,
                                 exp_field,
                                 sig_r[9:0]};

                        end

                    end

                end

            end

        end

    endfunction


    // ==========================================================
    // IEEE-754 Half Precision Multiplication
    // ==========================================================
    function [15:0] fp16_mul;
        input [15:0] x;
        input [15:0] y;

        reg sx, sy, sr;

        reg [4:0] exf, eyf;
        reg [9:0] fxf, fyf;

        reg [10:0] sigx, sigy;

        reg [21:0] product;

        reg [21:0] normalized_product;

        reg [11:0] sig_r;

        reg [4:0] exp_field;

        reg guard_bit;
        reg round_bit;
        reg sticky_bit;
        reg round_up;

        reg nan_x, nan_y;
        reg inf_x, inf_y;
        reg zero_x, zero_y;

        integer ex, ey;
        integer er;

        begin

            // --------------------------------------------------
            // Decode
            // --------------------------------------------------
            sx  = x[15];
            sy  = y[15];

            exf = x[14:10];
            eyf = y[14:10];

            fxf = x[9:0];
            fyf = y[9:0];

            sr = sx ^ sy;


            // --------------------------------------------------
            // Special values
            // --------------------------------------------------
            nan_x = (exf == 5'h1F) && (fxf != 0);
            nan_y = (eyf == 5'h1F) && (fyf != 0);

            inf_x = (exf == 5'h1F) && (fxf == 0);
            inf_y = (eyf == 5'h1F) && (fyf == 0);

            zero_x = (exf == 0) && (fxf == 0);
            zero_y = (eyf == 0) && (fyf == 0);


            // --------------------------------------------------
            // NaN
            // --------------------------------------------------
            if (nan_x || nan_y) begin

                fp16_mul = 16'h7E00;

            end

            // --------------------------------------------------
            // Infinity * Zero = NaN
            // --------------------------------------------------
            else if ((inf_x && zero_y) ||
                     (inf_y && zero_x)) begin

                fp16_mul = 16'h7E00;

            end

            // --------------------------------------------------
            // Infinity
            // --------------------------------------------------
            else if (inf_x || inf_y) begin

                fp16_mul =
                    {sr, 5'h1F, 10'b0};

            end

            // --------------------------------------------------
            // Zero
            // --------------------------------------------------
            else if (zero_x || zero_y) begin

                fp16_mul =
                    {sr, 15'b0};

            end

            else begin

                // --------------------------------------------------
                // Decode X
                // --------------------------------------------------
                if (exf == 0) begin

                    ex   = -14;
                    sigx = {1'b0, fxf};

                end
                else begin

                    ex   = exf - 15;
                    sigx = {1'b1, fxf};

                end


                // --------------------------------------------------
                // Decode Y
                // --------------------------------------------------
                if (eyf == 0) begin

                    ey   = -14;
                    sigy = {1'b0, fyf};

                end
                else begin

                    ey   = eyf - 15;
                    sigy = {1'b1, fyf};

                end


                // --------------------------------------------------
                // Multiply significands
                //
                // sigx and sigy are 11-bit fixed-point values
                // representing:
                //
                //       1.xxxxxxxxxx
                //
                // Product is therefore 22 bits.
                // --------------------------------------------------
                product = sigx * sigy;


                // --------------------------------------------------
                // Determine exponent
                //
                // For normal operands:
                //
                // 1.x * 1.y gives a product in [1,4)
                //
                // product[21] = 1 means product >= 2
                // product[20] = 1 means product >= 1
                // --------------------------------------------------
                if (product[21]) begin

                    normalized_product = product >> 1;

                    er = ex + ey + 1;

                end
                else begin

                    normalized_product = product;

                    er = ex + ey;

                end


                // --------------------------------------------------
                // At this point:
                //
                // normalized_product[20] is the hidden 1.
                //
                // [20:10] = 11-bit significand
                // [9]     = guard
                // [8]     = round
                // [7:0]   = sticky source
                // --------------------------------------------------

                // --------------------------------------------------
                // Handle underflow into subnormal range
                //
                // The smallest normal exponent is -14.
                // --------------------------------------------------
                if (er < -14) begin

                    normalized_product =
                        normalized_product >>
                        (-14 - er);

                    er = -14;

                end


                // --------------------------------------------------
                // Extract significand
                // --------------------------------------------------
                sig_r =
                    {1'b0,
                     normalized_product[20:10]};

                guard_bit =
                    normalized_product[9];

                round_bit =
                    normalized_product[8];

                sticky_bit =
                    |normalized_product[7:0];


                // --------------------------------------------------
                // Round-to-nearest-even
                // --------------------------------------------------
                round_up =
                    guard_bit &&
                    (round_bit ||
                     sticky_bit ||
                     sig_r[0]);


                if (round_up)
                    sig_r = sig_r + 1'b1;


                // --------------------------------------------------
                // Rounding overflow
                //
                // 1.111... rounded can become 10.000...
                // --------------------------------------------------
                if (sig_r == 12'd2048) begin

                    sig_r = 12'd1024;
                    er = er + 1;

                end


                // --------------------------------------------------
                // Overflow
                // --------------------------------------------------
                if (er > 15) begin

                    fp16_mul =
                        {sr, 5'h1F, 10'b0};

                end

                // --------------------------------------------------
                // Subnormal
                // --------------------------------------------------
                else if ((er == -14) &&
                         (sig_r < 11'd1024)) begin

                    fp16_mul =
                        {sr,
                         5'b00000,
                         sig_r[9:0]};

                end

                // --------------------------------------------------
                // Normal
                // --------------------------------------------------
                else begin

                    exp_field = er + 15;

                    fp16_mul =
                        {sr,
                         exp_field,
                         sig_r[9:0]};

                end

            end

        end

    endfunction


    always @(*) begin

    result = 16'h0000;

    if (enable) begin

        case (opcode)

            4'b0000: begin
                result = fp16_add(a, b);
            end

            4'b0001: begin
                result = fp16_mul(a, b);
            end

            default: begin
                result = 16'h0000;
            end

        endcase
    end

end

endmodule
