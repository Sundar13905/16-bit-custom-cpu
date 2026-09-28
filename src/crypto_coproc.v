//DO NOT MODIFY THIS MODULE
module key_expander (
    input [15:0] KEY_16BIT,
    output reg [127:0] KEY_128BIT
);  
    reg [15:0] seed;
    integer i;
    
    always @(*) begin
        seed = KEY_16BIT;
        KEY_128BIT = 128'h0;
        
        for (i = 0; i < 8; i = i + 1) begin
            seed = seed ^ (seed << 7);
            seed = seed ^ (seed >> 9);
            seed = seed ^ (seed << 8);
            KEY_128BIT[i*16 +: 16] = seed;
        end
    end
endmodule


//DO NOT MODIFY THIS MODULE
module round_function (
    input [15:0] round_data_in,
    input [15:0] round_key_in,
    output [15:0] round_data_out
);
    wire [7:0] L_in, R_in;
    wire [7:0] L_out, R_out;
    wire [7:0] F_result;
    
    assign L_in = round_data_in[15:8];
    assign R_in = round_data_in[7:0];
    
    assign F_result =
        (R_in ^ round_key_in[7:0]) +
        round_key_in[15:8];
    
    assign L_out = R_in;
    assign R_out = L_in ^ F_result;
    
    assign round_data_out = {L_out, R_out};
endmodule


// ----------------------------------------------------------
// INVERSE ROUND FUNCTION
// ----------------------------------------------------------
module inverse_round_function (
    input  [15:0] round_data_in,
    input  [15:0] round_key_in,
    output [15:0] round_data_out
);

    wire [7:0] L_in;
    wire [7:0] R_in;
    wire [7:0] L_out;
    wire [7:0] R_out;
    wire [7:0] F_result;

    assign L_in = round_data_in[15:8];
    assign R_in = round_data_in[7:0];

    // Inverse of:
    //
    // L_out = R_in
    // R_out = L_in ^ F(R_in, K)
    //
    // Therefore:
    //
    // R_original = L_in
    // L_original = R_in ^ F(L_in, K)

    assign F_result =
        (L_in ^ round_key_in[7:0]) +
        round_key_in[15:8];

    assign L_out = R_in ^ F_result;
    assign R_out = L_in;

    assign round_data_out = {L_out, R_out};

endmodule


// ----------------------------------------------------------
// CRYPTOGRAPHIC CO-PROCESSOR
// ----------------------------------------------------------
module crypto_coproc (
    input  [15:0] data_in,
    input          enc,
    input          dec,
    output [15:0] data_out
);

    // DO NOT CHANGE THIS KEY
    parameter MASTER_KEY = 16'h1EEE;

    wire [127:0] expanded_key;

    key_expander key_exp (
        .KEY_16BIT  (MASTER_KEY),
        .KEY_128BIT (expanded_key)
    );

    wire [15:0] key0;
    wire [15:0] key1;
    wire [15:0] key2;
    wire [15:0] key3;
    wire [15:0] key4;
    wire [15:0] key5;
    wire [15:0] key6;
    wire [15:0] key7;

    assign key0 = expanded_key[127:112];
    assign key1 = expanded_key[111:96];
    assign key2 = expanded_key[95:80];
    assign key3 = expanded_key[79:64];
    assign key4 = expanded_key[63:48];
    assign key5 = expanded_key[47:32];
    assign key6 = expanded_key[31:16];
    assign key7 = expanded_key[15:0];

    // ------------------------------------------------------
    // ENCRYPTION
    // ------------------------------------------------------

    wire [15:0] enc_data [0:8];

    assign enc_data[0] = data_in;

    round_function enc_round0 (
        .round_data_in  (enc_data[0]),
        .round_key_in   (key0),
        .round_data_out (enc_data[1])
    );

    round_function enc_round1 (
        .round_data_in  (enc_data[1]),
        .round_key_in   (key1),
        .round_data_out (enc_data[2])
    );

    round_function enc_round2 (
        .round_data_in  (enc_data[2]),
        .round_key_in   (key2),
        .round_data_out (enc_data[3])
    );

    round_function enc_round3 (
        .round_data_in  (enc_data[3]),
        .round_key_in   (key3),
        .round_data_out (enc_data[4])
    );

    round_function enc_round4 (
        .round_data_in  (enc_data[4]),
        .round_key_in   (key4),
        .round_data_out (enc_data[5])
    );

    round_function enc_round5 (
        .round_data_in  (enc_data[5]),
        .round_key_in   (key5),
        .round_data_out (enc_data[6])
    );

    round_function enc_round6 (
        .round_data_in  (enc_data[6]),
        .round_key_in   (key6),
        .round_data_out (enc_data[7])
    );

    round_function enc_round7 (
        .round_data_in  (enc_data[7]),
        .round_key_in   (key7),
        .round_data_out (enc_data[8])
    );


    // ------------------------------------------------------
    // DECRYPTION
    // ------------------------------------------------------

    wire [15:0] dec_data [0:8];

    assign dec_data[0] = data_in;

    inverse_round_function dec_round0 (
        .round_data_in  (dec_data[0]),
        .round_key_in   (key7),
        .round_data_out (dec_data[1])
    );

    inverse_round_function dec_round1 (
        .round_data_in  (dec_data[1]),
        .round_key_in   (key6),
        .round_data_out (dec_data[2])
    );

    inverse_round_function dec_round2 (
        .round_data_in  (dec_data[2]),
        .round_key_in   (key5),
        .round_data_out (dec_data[3])
    );

    inverse_round_function dec_round3 (
        .round_data_in  (dec_data[3]),
        .round_key_in   (key4),
        .round_data_out (dec_data[4])
    );

    inverse_round_function dec_round4 (
        .round_data_in  (dec_data[4]),
        .round_key_in   (key3),
        .round_data_out (dec_data[5])
    );

    inverse_round_function dec_round5 (
        .round_data_in  (dec_data[5]),
        .round_key_in   (key2),
        .round_data_out (dec_data[6])
    );

    inverse_round_function dec_round6 (
        .round_data_in  (dec_data[6]),
        .round_key_in   (key1),
        .round_data_out (dec_data[7])
    );

    inverse_round_function dec_round7 (
        .round_data_in  (dec_data[7]),
        .round_key_in   (key0),
        .round_data_out (dec_data[8])
    );


    // ------------------------------------------------------
    // OUTPUT SELECT
    // ------------------------------------------------------

    assign data_out =
        enc ? enc_data[8] :
        dec ? dec_data[8] :
              16'b0;

endmodule
