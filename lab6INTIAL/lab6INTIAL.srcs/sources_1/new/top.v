`timescale 1ns / 1ps

module top(
    input clkin,
    input btnU, //global reset
    input btnC, //start game/go
    input btnR, //move right
    input btnL, //move left
    input btnD, //drop apple logic
    input [15:0] sw,    //debug + apple select for milestone
    output [15:0] led,  //lives
   
    //7-seg
    output [3:0] an,
    output [6:0] seg,
    output dp,
   
    //vga
    output Hsync,
    output Vsync,
    output[3:0] vgaRed,
    output[3:0] vgaGreen,
    output[3:0] vgaBlue  
    );
   
//---------------------------------------------------------------------------
// LFSR and Target
//---------------------------------------------------------------------------

    wire [7:0] rnd_stream;
    wire [3:0] tgt_val;
    wire [7:0] tgt8;  
    wire load_spawn;
    wire load_target;
    wire running;
    wire go_fsm;
    wire clk, digsel;
   
    assign load_target = 1'b0;
   
    wire rnd_adv;
    assign rnd_adv = 1'b1;

    lfsr rand (
        .clk(clk),
        .reset(btnU),
        .en(rnd_adv),
        .Lfsr(rnd_stream)
    );
       
    FDRE #(.INIT(1'b0)) ltoT_0[3:0] (.C({4{clk}}), .R(4'b0), .CE({4{load_target}}), .D(rnd_stream[3:0]), .Q(tgt_val[3:0]));
       
    assign tgt8 = {2'b00, tgt_val, 2'b00};  
   
   
//---------------------------------------------------------------------------
// Some declarations for stuff used later
//---------------------------------------------------------------------------

    wire two_secs, four_secs;
    wire [3:0] scan_vec;
    wire [15:0] disp_bus;
    wire [3:0] hex_sel;
    wire [6:0] seg_raw;
       
    wire life_down_pulse;
    wire life_up_pulse;
    wire [2:0] lives;

    wire reset_timer;
    assign reset_timer = btnU;
    
    
    wire game_over;
    assign game_over = (lives == 3'd0); 
    
// -------------------
// 7-seg scan + blanking
// -------------------
    wire [3:0] scan_vec_use;
    assign scan_vec_use = game_over ? scan_vec : (scan_vec & 4'b0011);
    
    // anodes are active-low
    assign an = ~scan_vec_use;
    
    // blank left digits (AN3/AN2) by turning all segments off (segments active-low)
    wire sel_left;
    assign sel_left = (~an[3]) | (~an[2]);
    assign seg = sel_left ? 7'b1111111 : seg_raw;
    
    // dp is active-low: 0 lights it
    assign dp  = game_over ? 1'b0 : 1'b1;
   
   
// ------------------------------------------------------------
// Latch apple type per spawn
// ------------------------------------------------------------
    wire golden_lat_0, golden_lat_0_n;
    wire golden_lat_1, golden_lat_1_n;
   
    assign golden_lat_0_n =
            btnU ? 1'b0 :
            load_spawn_0 ? make_golden_0 :
                          golden_lat_0;
   
    assign golden_lat_1_n =
            btnU ? 1'b0 :
            load_spawn_1 ? make_golden_1 :
                          golden_lat_1;
   
    FDRE #(.INIT(1'b0)) GOLD_LAT0 (.C(clk), .R(1'b0), .CE(1'b1), .D(golden_lat_0_n), .Q(golden_lat_0));
    FDRE #(.INIT(1'b0)) GOLD_LAT1 (.C(clk), .R(1'b0), .CE(1'b1), .D(golden_lat_1_n), .Q(golden_lat_1));
       
   
// ------------------------------------------------------------
// SCORE (00..99) shown on 2 rightmost 7-seg digits
// ------------------------------------------------------------

    wire score_inc;
    wire do_score_0_eff, do_score_1_eff;
    assign do_score_0_eff = do_score_0 & ~golden_lat_0;
    assign do_score_1_eff = do_score_1 & ~golden_lat_1;
   
    assign score_inc = do_score_0_eff | (do_score_1_eff & ~do_score_0_eff);
   
    wire [3:0] score_ones, score_tens;
    wire [3:0] score_ones_n, score_tens_n;
   
    wire score_at_99;
    assign score_at_99 = (score_tens == 4'd9) & (score_ones == 4'd9);
   
    assign score_ones_n =
        btnU ? 4'd0 :
        score_at_99 ? score_ones :
        score_inc ?
            (score_ones == 4'd9 ? 4'd0 : (score_ones + 4'd1)) :
        score_ones;
   
    assign score_tens_n =
        btnU ? 4'd0 :
        score_at_99 ? score_tens :
        score_inc ?
            (score_ones == 4'd9 ? (score_tens + 4'd1) : score_tens) :
        score_tens;
   
    FDRE #(.INIT(1'b0)) SCORE_ONES_FF [3:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(score_ones_n), .Q(score_ones));
    FDRE #(.INIT(1'b0)) SCORE_TENS_FF [3:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(score_tens_n), .Q(score_tens));
   
    // Put score on rightmost digits: N[3:0]=ones, N[7:4]=tens (typical selector wiring)
    //assign disp_bus = {4'h0, 4'h0, score_tens, score_ones};
    assign disp_bus = {4'h0, 4'h0, score_tens, score_ones}; 
       
// ------------------------------------------------------------
// LIVES counter (0..4), start at 4
// ------------------------------------------------------------
    wire [2:0] lives_n;
   
    // Priority: if both happen same cycle, life_down wins.
    assign lives_n =
        btnU ? 3'd4 :
        life_down_pulse ? (lives == 3'd0 ? 3'd0 : (lives - 3'd1)) :
        life_up_pulse   ? (lives == 3'd4 ? 3'd4 : (lives + 3'd1)) :
                          lives;
   
    // IMPORTANT (lab rule-friendly): don't use async reset pin.
    // Keep .R(1'b0) and handle reset in D logic (above).
    FDRE #(.INIT(1'b0)) LIVES0 (.C(clk), .R(1'b0), .CE(1'b1), .D(lives_n[0]), .Q(lives[0]));
    FDRE #(.INIT(1'b0)) LIVES1 (.C(clk), .R(1'b0), .CE(1'b1), .D(lives_n[1]), .Q(lives[1]));
    FDRE #(.INIT(1'b1)) LIVES2 (.C(clk), .R(1'b0), .CE(1'b1), .D(lives_n[2]), .Q(lives[2]));
// ------------------------------------------------------------
// GAME OVER when lives==0
// ------------------------------------------------------------ 
   
    wire running_n;

    assign running_n =
        btnU      ? 1'b0 :
        game_over ? 1'b0 :
        start_pulse ? 1'b1 :
        running;
   
    FDRE #(.INIT(1'b0)) RUN_FF (.C(clk), .R(1'b0), .CE(1'b1), .D(running_n), .Q(running));
   
    assign go_fsm = running;   // (game_over already forces running low)  
   
// ------------------------------------------------------------
// LED display: rightmost 4 LEDs show lives (4->1111, 0->0000)
// ------------------------------------------------------------
    wire [3:0] led_lives;
   
    assign led_lives =
        (lives == 3'd4) ? 4'b1111 :
        (lives == 3'd3) ? 4'b0111 :
        (lives == 3'd2) ? 4'b0011 :
        (lives == 3'd1) ? 4'b0001 :
                          4'b0000;
   
    assign led = {12'b0, led_lives};
//---------------------------------------------------------------------------
// Time counter
//---------------------------------------------------------------------------

    wire [7:0] time_view;
    wire [5:0] time_core;
   
    wire [15:0] hpx, vpx;
    wire active;
   
    wire frame_tick;
    assign frame_tick = (hpx == 16'd0) & (vpx == 16'd0);
           
    time_counter TC_o (
        .clk(clk),
        .inc(frame_tick),
        .reset(reset_timer),
        .Count(time_core)
    );
           
    assign time_view = {4'b0000, time_core[5:2]};
    assign two_secs  = time_core[3];
    assign four_secs = time_core[4];
   
   
//---------------------------------------------------------------------------
// Ringcounter + Selector + Hex7Seg
//---------------------------------------------------------------------------
   
    ringCounter RC_o(
        .clk(clk),
        .advance(digsel),
        .reset(1'b0),
        .Ring(scan_vec)
    );
   
    selector sel_o (
        .Sel(scan_vec),
        .N(disp_bus),
        .H(hex_sel)
    );
   
    hex7seg hex_o (
        .N(hex_sel),
        .Seg(seg_raw)
    );
   
    labVGA_clks not_so_slow(
        .clkin(clkin),
        .greset(btnU),
        .clk(clk),
        .digsel(digsel)
    );

//---------------------------------------------------------------------------
// clock logic
// edgeDetectors:
//---------------------------------------------------------------------------

    wire l_pulse, r_pulse, d_pulse, start_pulse;
    edgeDetector startEdge(.clk(clk), .reset(1'b0), .button(btnC), .edge_o(start_pulse));
    edgeDetector detectL(.clk(clk), .reset(1'b0), .button(btnL), .edge_o(l_pulse));
    edgeDetector detectR(.clk(clk), .reset(1'b0), .button(btnR), .edge_o(r_pulse));
    edgeDetector detectD(.clk(clk),  .reset(1'b0), .button(btnD),.edge_o(d_pulse));
   
   wire initDone, initDonenxt;
   assign initDonenxt = btnU ? 1'b0 : 1'b1;
   FDRE #(.INIT(1'b0)) INITDONEFF (.C(clk), .R(1'b0), .CE(1'b1), .D(initDonenxt), .Q(initDone));
   
    // pixelAddress
    pixelAddress PA(.clk(clk), .reset(1'b0), .hpx(hpx), .vpx(vpx), .active(active));
   

    //syncs
    wire hsync_raw, vsync_raw;
    syncs SYNCLOGIC(.hpx(hpx), .vpx(vpx), .hsync(hsync_raw), .vsync(vsync_raw));
    FDRE #(.INIT(1'b1)) Hsync_FF (.C(clk), .R(1'b0), .CE(1'b1),  .D(hsync_raw), .Q(Hsync));
    FDRE #(.INIT(1'b1)) Vsync_FF (.C(clk), .R(1'b0), .CE(1'b1),  .D(vsync_raw), .Q(Vsync));
   
//     //movement counter
//     wire [17:0] moveCount;
//     wire [17:0] moveCountnxt;
//     wire moveTick;
     
//     FDRE #(.INIT(1'b0)) moveCountFF [17:0] (.C(clk), .R(btnU), .CE(1'b1), .D(moveCountnxt), .Q(moveCount));
     
//     //PLAYER MOVE SPEED!!! <- editiable to make the game more playable :))
//     //currently 18'd200000 -> 125 move/sec
//     assign moveTick = (moveCount == 18'd200000);
//     assign moveCountnxt = btnU ? 18'd0 : moveTick ? 18'd0 : moveCount + 18'd1;
     
// ------------------------------------------------------------
// Player movement enable (only after btnC has started the game)
// ------------------------------------------------------------
wire can_move;
assign can_move = running & ~game_over;   // game_over already forces running low, but safe

// ------------------------------------------------------------
// movement counter (only runs while can_move)
// ------------------------------------------------------------
    wire [17:0] moveCount;
    wire [17:0] moveCountnxt;
    wire moveTick;
    
    // IMPORTANT: .R should be 1'b0 per lab rule; handle reset in D logic
    FDRE #(.INIT(1'b0)) moveCountFF [17:0] ( .C(clk), .R(1'b0), .CE(1'b1), .D(moveCountnxt), .Q(moveCount));
    
    // Only generate tick while allowed to move
    assign moveTick = can_move & (moveCount == 18'd200000);
    
    // Hold at 0 while paused; count only while can_move
    assign moveCountnxt =
        btnU      ? 18'd0 :
        ~can_move ? 18'd0 :
        moveTick  ? 18'd0 :
                    (moveCount + 18'd1);
    
// ------------------------------------------------------------
// Player X position register
// ------------------------------------------------------------
    wire [15:0] playerMove;
    wire [15:0] playerMove_next;
    
    // Border/player limits
    wire at_left_edge;
    wire at_right_edge;
    assign at_left_edge  = (playerMove <= 16'd8);
    assign at_right_edge = (playerMove >= 16'd622);
    
    // Gate button pulses and held-button motion
    wire l_pulse_g, r_pulse_g;
    assign l_pulse_g = l_pulse & can_move;
    assign r_pulse_g = r_pulse & can_move;
    
    wire move_left;
    assign move_left  = (l_pulse_g | (can_move & ~btnR & btnL & moveTick)) & ~at_left_edge;
    
    wire move_right;
    assign move_right = (r_pulse_g | (can_move & ~btnL & btnR & moveTick)) & ~at_right_edge;
    
    // Next-state (moves via 1 pixel)
    assign playerMove_next = (btnU | ~initDone) ? 16'd315 :
                            ~can_move ? playerMove :   // freeze player before start
                            move_left ? (playerMove - 16'd1) :
                            move_right ? (playerMove + 16'd1) :
                                                 playerMove;
    
    FDRE #(.INIT(1'b0)) PLAYER_FF [15:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(playerMove_next), .Q(playerMove));
   
    wire trunk;
    wire leaves;

    // Green Ground
    wire ground;
    assign ground = active & (vpx >= 16'd432);
   
    // Player -> yellow
    wire player;
    assign player = active & (hpx >= playerMove) & (hpx < playerMove + 16'd10) & (vpx >= 16'd422) & (vpx < 16'd432);
   
    // Border  -> red:
    wire border;
    assign border = active & ( (hpx < 16'd8) | (hpx >= 16'd632) | (vpx < 16'd8) | (vpx >= 16'd472) );    
   
   //TREE & CANOPY LOGIC
   
    assign trunk = active
    & (hpx >= 16'd300) & (hpx < 16'd340) //40 pxl wide, centered
    & (vpx >= 16'd300) & (vpx < 16'd432); //down to ground
   
    assign leaves = active
    & (hpx >= 16'd200) & (hpx < 16'd440) //wider than trunk
    & (vpx >= 16'd150) & (vpx < 16'd300); //above trunk
   
    //APPLE DISPLAY LOGIC

    wire a1, a2, a3, a4, a5, a6, a7, a8;
    assign a1 = active & (hpx >= 16'd210) & (hpx < 16'd220) & (vpx >= 16'd170) & (vpx < 16'd180);
    assign a2 = active & (hpx >= 16'd275) & (hpx < 16'd285) & (vpx >= 16'd170) & (vpx < 16'd180);
    assign a3 = active & (hpx >= 16'd342) & (hpx < 16'd352) & (vpx >= 16'd170) & (vpx < 16'd180);
    assign a4 = active & (hpx >= 16'd408) & (hpx < 16'd418) & (vpx >= 16'd170) & (vpx < 16'd180);
    assign a5 = active & (hpx >= 16'd223) & (hpx < 16'd233) & (vpx >= 16'd270) & (vpx < 16'd280);
    assign a6 = active & (hpx >= 16'd289) & (hpx < 16'd299) & (vpx >= 16'd270) & (vpx < 16'd280);
    assign a7 = active & (hpx >= 16'd355) & (hpx < 16'd365) & (vpx >= 16'd270) & (vpx < 16'd280);
    assign a8 = active & (hpx >= 16'd421) & (hpx < 16'd431) & (vpx >= 16'd270) & (vpx < 16'd280);

//---------------------------------------------------------------------------
// SWITCH LOGIC
//---------------------------------------------------------------------------

    // enable per slot (use sw[0..7])
    wire en0;
    assign en0 = sw[0]; // top row slot a1
    wire en1;
    assign en1 = sw[2]; // top row slot a2
    wire en2;
    assign en2 = sw[4]; // top row slot a3
    wire en3;
    assign en3 = sw[6]; // top row slot a4
   
    wire en4;
    assign en4 = sw[1]; // bottom row slot a5
    wire en5;
    assign en5 = sw[3]; // bottom row slot a6
    wire en6;
    assign en6 = sw[5]; // bottom row slot a7
    wire en7;
    assign en7 = sw[7]; // bottom row slot a8
   
    wire [7:0] en;
    assign en = {en7,en6,en5,en4,en3,en2,en1,en0};
   
    wire any_en;
    assign any_en = |en;   // 1 if any enable switch is ON
           
    wire [2:0] slot_raw;
    assign slot_raw = rnd_stream[2:0] ^ rnd_stream[5:3];

    // function-like inline "next enabled" chooser (combinational)
    wire [2:0] slot_pick0;
    assign slot_pick0 = slot_raw;
    wire [2:0] slot_pick1;
    assign slot_pick1 = slot_raw + 3'd1;
    wire [2:0] slot_pick2;
    assign slot_pick2 = slot_raw + 3'd2;
    wire [2:0] slot_pick3;
    assign slot_pick3 = slot_raw + 3'd3;
    wire [2:0] slot_pick4;
    assign slot_pick4 = slot_raw + 3'd4;
    wire [2:0] slot_pick5;
    assign slot_pick5 = slot_raw + 3'd5;
    wire [2:0] slot_pick6;
    assign slot_pick6 = slot_raw + 3'd6;
    wire [2:0] slot_pick7;
    assign slot_pick7 = slot_raw + 3'd7;
   
    wire [2:0] slot_enforced;
    assign slot_enforced =
        en[slot_pick0] ? slot_pick0 :
        en[slot_pick1] ? slot_pick1 :
        en[slot_pick2] ? slot_pick2 :
        en[slot_pick3] ? slot_pick3 :
        en[slot_pick4] ? slot_pick4 :
        en[slot_pick5] ? slot_pick5 :
        en[slot_pick6] ? slot_pick6 :
        en[slot_pick7] ? slot_pick7 :
        slot_raw;
   
    wire [2:0] slot;
    assign slot = any_en ? slot_enforced : slot_raw;

   
//---------------------------------------------------------------------------
// APPLE FSM TOP INSTANTIATION
//---------------------------------------------------------------------------

    // --- Apple position registers (one falling apple) ---
    // =============================
    // APPLE 0 signals
    // =============================
   
    wire slot_red_0, slot_red_1;
    wire allow_drop_0, allow_drop_1;

    wire [15:0] appleX_0, appleX_next_0;
    wire [15:0] appleY_0, appleY_next_0;
   

    wire make_golden_0;
    wire caught_0;
    wire missed_0;
    wire hit_ground_0;
   
    wire load_spawn_0;
    wire ramp_en_0, ramp_rst_0;
    wire flash_en_0, flash_rst_0;
    wire ready_0;
    wire falling_0;
    wire do_score_0, do_life_down_0, do_life_up_0;
    wire flash_on_0;
    wire is_golden_state_0;
   
    wire [15:0] ramp_count_0, flash_count_0;
    wire ramp_done_0, flash_done_0;
   
    wire [2:0] slot_lat_0;
    wire [2:0] slot_lat_next_0;
   
    wire [15:0] wait_target_0, wait_target_next_0;
    wire [15:0] wait_count_0;
   
// ------------------------------------------------------------
// LIVES event pulses (combine apples)
// ------------------------------------------------------------
   
    wire do_life_down_0_eff;
    wire do_life_down_1_eff;
   
    assign do_life_down_0_eff = do_life_down_0 & ~golden_lat_0;
    assign do_life_down_1_eff = do_life_down_1 & ~golden_lat_1;
   
    assign life_down_pulse = do_life_down_0_eff | do_life_down_1_eff;
   
    // golden catch -> life up
    assign life_up_pulse   = do_life_up_0   | do_life_up_1;
   


// ------------------------------------------------------------
    // APPLE 1 signals
// ------------------------------------------------------------
   
    wire [15:0] appleX_1, appleX_next_1;
    wire [15:0] appleY_1, appleY_next_1;
   
    wire make_golden_1;
    wire caught_1;
    wire missed_1;
    wire hit_ground_1;
   
    wire load_spawn_1;
    wire ramp_en_1, ramp_rst_1;
    wire flash_en_1, flash_rst_1;
    wire ready_1;
    wire falling_1;
    wire do_score_1, do_life_down_1, do_life_up_1;
    wire flash_on_1;
    wire is_golden_state_1;
   
    wire [15:0] ramp_count_1, flash_count_1;
    wire ramp_done_1, flash_done_1;
   
    wire [2:0] slot_lat_1;
    wire [2:0] slot_lat_next_1;
   
    wire [15:0] wait_target_1, wait_target_next_1;
    wire [15:0] wait_count_1;
   
    assign load_spawn = load_spawn_0 | load_spawn_1;
   

// Apples repition fix
    wire [15:0] wait_target_0_safe;
    wire [15:0] wait_target_1_safe;
   
    assign wait_target_0_safe = (wait_target_0 == 16'd0) ? 16'd60 : wait_target_0;
    assign wait_target_1_safe = (wait_target_1 == 16'd0) ? 16'd90 : wait_target_1;

    wire wait_hit_0;
    wire wait_hit_1;
    wire chosen_fsm_0;
    wire chosen_fsm_1;
   
    wire chosen0_raw, chosen1_raw;

    assign chosen0_raw = ready_0 & frame_tick & wait_hit_0 & allow_drop_0;
    assign chosen1_raw = ready_1 & frame_tick & wait_hit_1 & allow_drop_1;
   
    assign chosen_fsm_0 = chosen0_raw;
    assign chosen_fsm_1 = chosen1_raw & ~chosen0_raw;   // block apple1 if apple0 also hits
   
    assign allow_drop_0 = slot_red_0 | is_golden_state_0;
    assign allow_drop_1 = slot_red_1 | is_golden_state_1;
   
    assign wait_hit_0 = (wait_count_0 >= wait_target_0_safe);
    assign wait_hit_1 = (wait_count_1 >= wait_target_1_safe);
   

// ------------------------------------------------------------
// Apple 0 position
// ------------------------------------------------------------                                    

    FDRE #(.INIT(1'b0)) APPLEX_FF_0 [15:0] (.C(clk), .R(btnU), .CE(1'b1), .D(appleX_next_0), .Q(appleX_0));
   
    wire [15:0] fall_step_0;
    assign fall_step_0 = is_golden_state_0 ? 16'd2 : 16'd1;
   
   
    FDRE #(.INIT(1'b0)) APPLEY_FF_0 [15:0] (.C(clk), .R(btnU), .CE(1'b1), .D(appleY_next_0), .Q(appleY_0));

// ------------------------------------------------------------
// Apple 1 position
// ------------------------------------------------------------

    FDRE #(.INIT(1'b0)) APPLEX_FF_1 [15:0] (.C(clk), .R(btnU), .CE(1'b1),.D(appleX_next_1), .Q(appleX_1));
   
    wire [15:0] fall_step_1;
    assign fall_step_1 = is_golden_state_1 ? 16'd2 : 16'd1;
   
   
    FDRE #(.INIT(1'b0)) APPLEY_FF_1 [15:0] (.C(clk), .R(btnU), .CE(1'b1),.D(appleY_next_1), .Q(appleY_1));
   
    FDRE #(.INIT(1'b0)) SLOT_LAT_FF_0 [2:0] (.C(clk), .R(btnU), .CE(1'b1), .D(slot_lat_next_0), .Q(slot_lat_0));
    FDRE #(.INIT(1'b0)) SLOT_LAT_FF_1 [2:0] (.C(clk), .R(btnU), .CE(1'b1), .D(slot_lat_next_1), .Q(slot_lat_1));

   
// ------------------------------------------------------------
// Per-apple slot picks
// ------------------------------------------------------------

    // Raw picks
    wire [2:0] slot_pick_0_raw;
    assign slot_pick_0_raw = slot;
   
    wire [2:0] slot_pick_1_raw;
    assign slot_pick_1_raw = rnd_stream[5:3] ^ rnd_stream[2:0];
   
    // Apple 0: avoid apple 1's occupied slot (slot_lat_1) if apple1 is active
    wire [2:0] slot_pick_0;
    assign slot_pick_0 =
        (apple_active_1 & (slot_pick_0_raw == slot_lat_1)) ? (slot_pick_0_raw + 3'd1) :
                                                              slot_pick_0_raw;
   
    // Apple 1: avoid apple0's pick, then avoid apple0's occupied slot if apple0 is active
    wire [2:0] slot_pick_1_fixed;
    assign slot_pick_1_fixed =
        (slot_pick_1_raw == slot_pick_0) ? (slot_pick_1_raw + 3'd1) :
                                           slot_pick_1_raw;
   
    // helper: detect "neighbor" (circular mod-8)
    wire neigh_1_of_0;
    assign neigh_1_of_0 =
        (slot_pick_1_raw == slot_pick_0) |
        (slot_pick_1_raw == (slot_pick_0 + 3'd1)) |
        (slot_pick_1_raw == (slot_pick_0 + 3'd7));  // -1 mod 8
   
    wire [2:0] slot_pick_1;
    assign slot_pick_1 = neigh_1_of_0 ? (slot_pick_1_raw + 3'd3) : slot_pick_1_raw;
   
    // Use the new pick immediately during the spawn cycle, otherwise use the latched slot
    wire [2:0] slot_use_0;
    wire [2:0] slot_use_1;
   
    assign slot_use_0 = load_spawn_0 ? slot_pick_0 : slot_lat_0;
    assign slot_use_1 = load_spawn_1 ? slot_pick_1 : slot_lat_1;
   
    // ------------------------------------------------------------
    // Slot -> X/Y mapping PER APPLE
    // ------------------------------------------------------------
   
    wire [15:0] slotX_spawn_0;
    wire [15:0] slotY_spawn_0;
   
    wire [15:0] slotX_spawn_1;
    wire [15:0] slotY_spawn_1;
   
    assign slotX_spawn_0 =
    (slot_pick_0 == 3'd0) ? 16'd210 :
    (slot_pick_0 == 3'd1) ? 16'd275 :
    (slot_pick_0 == 3'd2) ? 16'd342 :
    (slot_pick_0 == 3'd3) ? 16'd408 :
    (slot_pick_0 == 3'd4) ? 16'd223 :
    (slot_pick_0 == 3'd5) ? 16'd289 :
    (slot_pick_0 == 3'd6) ? 16'd355 :
                            16'd421;

    assign slotY_spawn_0 =
        (slot_pick_0 <= 3'd3) ? 16'd170 : 16'd270;
       
    assign slotX_spawn_1 =
    (slot_pick_1 == 3'd0) ? 16'd210 :
    (slot_pick_1 == 3'd1) ? 16'd275 :
    (slot_pick_1 == 3'd2) ? 16'd342 :
    (slot_pick_1 == 3'd3) ? 16'd408 :
    (slot_pick_1 == 3'd4) ? 16'd223 :
    (slot_pick_1 == 3'd5) ? 16'd289 :
    (slot_pick_1 == 3'd6) ? 16'd355 :
                             16'd421;
   
    assign slotY_spawn_1 =
        (slot_pick_1 <= 3'd3) ? 16'd170 : 16'd270;

    // ------------------------------------------------------------
    // Use per-apple slotX/slotY on spawn
    // ------------------------------------------------------------
   
    assign appleX_next_0 = load_spawn_0 ? slotX_spawn_0 : appleX_0;
    assign appleX_next_1 = load_spawn_1 ? slotX_spawn_1 : appleX_1;
   
    assign appleY_next_0 =
        load_spawn_0 ? slotY_spawn_0 :
        (falling_0 & frame_tick & ~hit_ground_0) ? (appleY_0 + fall_step_0) :
        appleY_0;
   
    assign appleY_next_1 =
        load_spawn_1 ? slotY_spawn_1 :
        (falling_1 & frame_tick & ~hit_ground_1) ? (appleY_1 + fall_step_1) :
        appleY_1;
   
   
    // ------------------------------------------------------------
    // Latch the picked slot per apple
    // ------------------------------------------------------------
   
    assign slot_lat_next_0 = load_spawn_0 ? slot_pick_0 : slot_lat_0;
    assign slot_lat_next_1 = load_spawn_1 ? slot_pick_1 : slot_lat_1;
   
    // Golden probability: use a bit for now
   
    //assign make_golden = rnd_stream[0]; //SUPER FREQUENCT, GOOD FOR SHOWING G APPLES EXIST!! EXTRA CREDIT
//    assign make_golden_0 = (rnd_stream[3:0] == 4'b0000); //1 in 16 chance
//    assign make_golden_1 = (rnd_stream[7:4] == 4'b0000);
    
    assign make_golden_0 = (rnd_stream[4:0] == 5'b00000);  // 1 in 32
    assign make_golden_1 = (rnd_stream[7:3] == 5'b00000);  // 1 in 32

      //GOLDEN TESTING
//      assign make_golden_0 = rnd_stream[0];
//      assign make_golden_1 = rnd_stream[0];
   
    // Gameover for now
    wire over_fsm;
    assign over_fsm = 1'b0;
   
   
   // ground contact (ground starts at 432, apple is 10px tall => contact at Y=422)
    assign hit_ground_0 = (appleY_0 >= 16'd422);
    assign hit_ground_1 = (appleY_1 >= 16'd422);
   
    // missed only if THAT apple is falling and hits ground

    wire caught_lat_0, caught_lat_0_n;
    assign caught_lat_0_n =
        btnU         ? 1'b0 :
        load_spawn_0 ? 1'b0 :
        caught_0     ? 1'b1 :
                      caught_lat_0;
    FDRE #(.INIT(1'b0)) CAUGHTLAT0 (.C(clk), .R(1'b0), .CE(1'b1), .D(caught_lat_0_n), .Q(caught_lat_0));
   
    wire caught_lat_1, caught_lat_1_n;
    assign caught_lat_1_n =
        btnU         ? 1'b0 :
        load_spawn_1 ? 1'b0 :
        caught_1     ? 1'b1 :
                      caught_lat_1;
    FDRE #(.INIT(1'b0)) CAUGHTLAT1 (.C(clk), .R(1'b0), .CE(1'b1), .D(caught_lat_1_n), .Q(caught_lat_1));
   
    assign missed_0 = falling_0 & hit_ground_0 & ~caught_lat_0;
    assign missed_1 = falling_1 & hit_ground_1 & ~caught_lat_1;

    // ------------------------------------------------------------
    // Player vs Apple collision (1 pulse per catch) - PER APPLE
    // ------------------------------------------------------------
   
    // Player rect (10x10)
    wire [15:0] ply_x0, ply_x1, ply_y0, ply_y1;
    assign ply_x0 = playerMove;
    assign ply_x1 = playerMove + 16'd10;
    assign ply_y0 = 16'd422;
    assign ply_y1 = 16'd432;
   
    // Apple 0 rect
    wire [15:0] appleX_draw_0;
    wire [15:0] appleX_draw_1;
    wire [15:0] a0_x0, a0_x1, a0_y0, a0_y1;
    assign a0_x0 = appleX_draw_0;
    assign a0_x1 = appleX_draw_0 + 16'd10;
    assign a0_y0 = appleY_0;
    assign a0_y1 = appleY_0 + 16'd10;
   
    // Apple 1 rect
    wire [15:0] a1_x0, a1_x1, a1_y0, a1_y1;
    assign a1_x0 = appleX_draw_1;
    assign a1_x1 = appleX_draw_1 + 16'd10;
    assign a1_y0 = appleY_1;
    assign a1_y1 = appleY_1 + 16'd10;
   
    // Rectangle overlap test: (A left < B right) & (A right > B left) & same for Y
    wire ov0_x, ov0_y, overlap0;
    assign ov0_x = (ply_x0 < a0_x1) & (ply_x1 > a0_x0);
    assign ov0_y = (ply_y0 < a0_y1) & (ply_y1 > a0_y0);
    assign overlap0 = ov0_x & ov0_y;
   
    wire ov1_x, ov1_y, overlap1;
    assign ov1_x = (ply_x0 < a1_x1) & (ply_x1 > a1_x0);
    assign ov1_y = (ply_y0 < a1_y1) & (ply_y1 > a1_y0);
    assign overlap1 = ov1_x & ov1_y;
   
    // "Red apple only" scoring (golden should not score)
    // Catch ANY apple (red OR golden)
    wire collide_any_0;
    wire collide_any_1;
   
    assign collide_any_0 = falling_0 & overlap0 & ~hit_ground_0;
    assign collide_any_1 = falling_1 & overlap1 & ~hit_ground_1;
   
    // Edge-detect collision ONCE per apple (sampled on frame_tick)
    wire coll_prev_0, coll_prev_1;
    wire coll_prev_n0, coll_prev_n1;
   
    // Update prev only once per frame so it's stable
    assign coll_prev_n0 = btnU ? 1'b0 : (frame_tick ? collide_any_0 : coll_prev_0);
    assign coll_prev_n1 = btnU ? 1'b0 : (frame_tick ? collide_any_1 : coll_prev_1);
   
    FDRE #(.INIT(1'b0)) COLL_PREV0 (.C(clk), .R(1'b0), .CE(1'b1), .D(coll_prev_n0), .Q(coll_prev_0));
    FDRE #(.INIT(1'b0)) COLL_PREV1 (.C(clk), .R(1'b0), .CE(1'b1), .D(coll_prev_n1), .Q(coll_prev_1));
   
    // 1-frame pulse when collision first happens
    wire caught_pulse_0;
    wire caught_pulse_1;
    assign caught_pulse_0 = frame_tick & collide_any_0 & ~coll_prev_0;
    assign caught_pulse_1 = frame_tick & collide_any_1 & ~coll_prev_1;
   
    // Feed FSM "caught" inputs
    assign caught_0 = caught_pulse_0;
    assign caught_1 = caught_pulse_1;      

 // ------------------------------------------------------------
// Ramp + Flash counters (PER APPLE)
// ------------------------------------------------------------

    // Apple 0 counters
    time_counter RAMP_TC_0 (
        .clk(clk),
        .inc(ramp_en_0 & frame_tick),
        .reset(ramp_rst_0),
        .Count(ramp_count_0)
    );
    assign ramp_done_0 = (ramp_count_0 == 16'd239);
   
    time_counter FLASH_TC_0 (
        .clk(clk),
        .inc(flash_en_0 & frame_tick),
        .reset(flash_rst_0),
        .Count(flash_count_0)
    );
    assign flash_done_0 = (flash_count_0 == 16'd119);
   
    // Apple 1 counters
    time_counter RAMP_TC_1 (
        .clk(clk),
        .inc(ramp_en_1 & frame_tick),
        .reset(ramp_rst_1),
        .Count(ramp_count_1)
    );
    assign ramp_done_1 = (ramp_count_1 == 16'd239);
   
    time_counter FLASH_TC_1 (
        .clk(clk),
        .inc(flash_en_1 & frame_tick),
        .reset(flash_rst_1),
        .Count(flash_count_1)
    );
    assign flash_done_1 = (flash_count_1 == 16'd119);
   
   
    applefsm1 APPLE_FSM0 (
      .clk(clk),
      .go(go_fsm),
      .over(over_fsm),
      .frame_tick(frame_tick),
      .chosen(chosen_fsm_0),
      .caught(caught_0),
      .missed(missed_0),
      .ramp_done(ramp_done_0),
      .flash_done(flash_done_0),
      .make_golden(make_golden_0),
      .load_spawn(load_spawn_0),
      .ramp_en(ramp_en_0),
      .ramp_rst(ramp_rst_0),
      .flash_en(flash_en_0),
      .flash_rst(flash_rst_0),
      .ready(ready_0),
      .falling(falling_0),
      .do_score(do_score_0),
      .do_life_down(do_life_down_0),
      .do_life_up(do_life_up_0),
      .flash_on(flash_on_0),
      .is_golden_state(is_golden_state_0)
    );
   
    applefsm1 APPLE_FSM1 (
      .clk(clk),
      .go(go_fsm),
      .over(over_fsm),
      .frame_tick(frame_tick),
      .chosen(chosen_fsm_1),
      .caught(caught_1),
      .missed(missed_1),
      .ramp_done(ramp_done_1),
      .flash_done(flash_done_1),
      .make_golden(make_golden_1),
      .load_spawn(load_spawn_1),
      .ramp_en(ramp_en_1),
      .ramp_rst(ramp_rst_1),
      .flash_en(flash_en_1),
      .flash_rst(flash_rst_1),
      .ready(ready_1),
      .falling(falling_1),
      .do_score(do_score_1),
      .do_life_down(do_life_down_1),
      .do_life_up(do_life_up_1),
      .flash_on(flash_on_1),
      .is_golden_state(is_golden_state_1)
    );
   
    // --- MULTI-APPLE "round active" ---
    wire in_ramp_0, in_ramp_1;   //per-apple
    wire round_active;
   
    assign round_active =
        load_spawn_0 | in_ramp_0 | ready_0 | falling_0 |
        load_spawn_1 | in_ramp_1 | ready_1 | falling_1;
       
    assign in_ramp_0 = (~ready_0) & (~falling_0) & (~flash_on_0) & (~ramp_done_0)
                     & ((ramp_count_0 != 16'd0) | (ramp_en_0 & frame_tick));
   
    assign in_ramp_1 = (~ready_1) & (~falling_1) & (~flash_on_1) & (~ramp_done_1)
                     & ((ramp_count_1 != 16'd0) | (ramp_en_1 & frame_tick));  
                     
    // "apple occupies a slot" flag (used for spawn collision + hide logic)
    wire apple_active_0;
    wire apple_active_1;
   
    assign apple_active_0 = load_spawn_0 | in_ramp_0 | ready_0 | falling_0 | flash_on_0;
    assign apple_active_1 = load_spawn_1 | in_ramp_1 | ready_1 | falling_1 | flash_on_1;                        
   
// ------------------------------------------------------------
//Hide stationary apples
// ------------------------------------------------------------

    wire blink_0;
    wire blink_1;
   
    assign blink_0 = flash_count_0[2];
    assign blink_1 = flash_count_1[2];

    // ------------------------------------------------------------
    // Hide stationary apples for either apple's selected slot
    // ------------------------------------------------------------
    wire hide0;
    wire hide1;
   
    assign hide0 = (load_spawn_0 | in_ramp_0 | ready_0 | falling_0) | (flash_on_0 & ~blink_0);
    assign hide1 = (load_spawn_1 | in_ramp_1 | ready_1 | falling_1) | (flash_on_1 & ~blink_1);
   
    wire hide_slot0;
    wire hide_slot1;
    wire hide_slot2;
    wire hide_slot3;
    wire hide_slot4;
    wire hide_slot5;
    wire hide_slot6;
    wire hide_slot7;
   
    wire a1_draw;
    wire a2_draw;
    wire a3_draw;
    wire a4_draw;
    wire a5_draw;
    wire a6_draw;
    wire a7_draw;
    wire a8_draw;
   
   
    assign hide_slot0 = ((slot_use_0 == 3'd0) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd0) & hide1 & apple_active_1);
   
    assign hide_slot1 = ((slot_use_0 == 3'd1) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd1) & hide1 & apple_active_1);
   
    assign hide_slot2 = ((slot_use_0 == 3'd2) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd2) & hide1 & apple_active_1);
   
    assign hide_slot3 = ((slot_use_0 == 3'd3) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd3) & hide1 & apple_active_1);
   
    assign hide_slot4 = ((slot_use_0 == 3'd4) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd4) & hide1 & apple_active_1);
   
    assign hide_slot5 = ((slot_use_0 == 3'd5) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd5) & hide1 & apple_active_1);
   
    assign hide_slot6 = ((slot_use_0 == 3'd6) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd6) & hide1 & apple_active_1);
   
    assign hide_slot7 = ((slot_use_0 == 3'd7) & hide0 & apple_active_0) |
                        ((slot_use_1 == 3'd7) & hide1 & apple_active_1);
       
    assign a1_draw = a1 & ~hide_slot0;
    assign a2_draw = a2 & ~hide_slot1;
    assign a3_draw = a3 & ~hide_slot2;
    assign a4_draw = a4 & ~hide_slot3;
    assign a5_draw = a5 & ~hide_slot4;
    assign a6_draw = a6 & ~hide_slot5;
    assign a7_draw = a7 & ~hide_slot6;
    assign a8_draw = a8 & ~hide_slot7;
   

//---------------------------------------------------------------------------
// Apple wiggle logic (2 apples)
//---------------------------------------------------------------------------

   
    assign slot_red_0 = (rip_sel_0 == 6'd63);
    assign slot_red_1 = (rip_sel_1 == 6'd63);

    // ----------------------------
    // Apple 0 wiggle
    // ----------------------------
    wire [1:0] wiggle_ctr_0;
    wire [1:0] wiggle_ctr_next_0;
    wire signed [2:0] wiggle_offset_0;
   
    assign wiggle_ctr_next_0 =
        btnU ? 2'd0 :
        ((ready_0 & slot_red_0) & frame_tick) ? (wiggle_ctr_0 + 2'd1) :
        wiggle_ctr_0;
   
    FDRE #(.INIT(1'b0)) WIGGLE_FF_0 [1:0] (
        .C(clk),
        .R(1'b0),
        .CE(1'b1),
        .D(wiggle_ctr_next_0),
        .Q(wiggle_ctr_0)
    );
   
    assign wiggle_offset_0 =
        (wiggle_ctr_0 == 2'd0) ? 3'sd0 :
        (wiggle_ctr_0 == 2'd1) ? -3'sd1 :
        (wiggle_ctr_0 == 2'd2) ? 3'sd0 :
                                 3'sd1;
   
   
    // ----------------------------
    // Apple 1 wiggle
    // ----------------------------
    wire [1:0] wiggle_ctr_1;
    wire [1:0] wiggle_ctr_next_1;
    wire signed [2:0] wiggle_offset_1;
   
    assign wiggle_ctr_next_1 =
        btnU ? 2'd0 :
        ((ready_1 & slot_red_1) & frame_tick) ? (wiggle_ctr_1 + 2'd1) :
        wiggle_ctr_1;
   
    FDRE #(.INIT(1'b0)) WIGGLE_FF_1 [1:0] (
        .C(clk),
        .R(1'b0),
        .CE(1'b1),
        .D(wiggle_ctr_next_1),
        .Q(wiggle_ctr_1)
    );
   
    assign wiggle_offset_1 =
        (wiggle_ctr_1 == 2'd0) ? 3'sd0 :
        (wiggle_ctr_1 == 2'd1) ? -3'sd1 :
        (wiggle_ctr_1 == 2'd2) ? 3'sd0 :
                                 3'sd1;
   
// ------------------------------------------------------------
// Apple pixel draw + random fall timing (2 apples)
// ------------------------------------------------------------

    //------------------------------------------------------------
    // APPLE 0 draw (10x10)
    //------------------------------------------------------------
   
    assign appleX_draw_0 = (ready_0 & slot_red_0) ? (appleX_0 + wiggle_offset_0) : appleX_0;
   
    wire apple_pix_0;
    assign apple_pix_0 = active
        & (hpx >= appleX_draw_0) & (hpx < appleX_draw_0 + 16'd10)
        & (vpx >= appleY_0)      & (vpx < appleY_0      + 16'd10);
   
    // show apple during ramp/ready/fall
    wire apple_show_0;
    assign apple_show_0 = apple_active_0 & (in_ramp_0 | ready_0 | (falling_0 & ~hit_ground_0));
   
    wire fallingApple_0;
    assign fallingApple_0 = apple_pix_0 & apple_show_0;

   
    //------------------------------------------------------------
    // APPLE 1 draw (10x10)
    //------------------------------------------------------------

    assign appleX_draw_1 = (ready_1 & slot_red_1) ? (appleX_1 + wiggle_offset_1) : appleX_1;
   
    wire apple_pix_1;
    assign apple_pix_1 = active
        & (hpx >= appleX_draw_1) & (hpx < appleX_draw_1 + 16'd10)
        & (vpx >= appleY_1)      & (vpx < appleY_1      + 16'd10);
   
    // show apple during ramp/ready/fall
    wire apple_show_1;
    assign apple_show_1 = apple_active_1 & (in_ramp_1 | ready_1 | (falling_1 & ~hit_ground_1));
   
    wire fallingApple_1;
    assign fallingApple_1 = apple_pix_1 & apple_show_1;
   
   
    //------------------------------------------------------------
    // Combine falling apples for RGB mux
    //------------------------------------------------------------
   
    wire fallingApple_any;
    assign fallingApple_any = fallingApple_0 | fallingApple_1;
   
   
    // ------------------------------------------------------------
    // Random fall timing (auto-chosen) - APPLE 0
    // ------------------------------------------------------------
   
    wire [15:0] wait_target_sum_0;
    wire [15:0] rnd_delay_0;
    assign rnd_delay_0 = {9'b0, rnd_stream[6:0]};   // 0..127
   
    wire unused_cout_0, unused_ovfl_0;
    adder16 ADD_WAIT_0 (
      .A(rnd_delay_0),
      .B(16'd30),
      .cin(1'b0),
      .S(wait_target_sum_0),
      .cout(unused_cout_0),
      .ovfl(unused_ovfl_0)
    );
   
    // latch target when we spawn a new apple (apple 0)
    assign wait_target_next_0 = load_spawn_0 ? wait_target_sum_0 : wait_target_0;
   
    FDRE #(.INIT(1'b0)) WAIT_TGT_FF_0 [15:0] (.C(clk), .R(btnU), .CE(1'b1), .D(wait_target_next_0), .Q(wait_target_0));
   
    // reset the wait counter whenever we are NOT in READY, or on spawn (apple 0)
    wire wait_rst_0;
    assign wait_rst_0 = btnU | load_spawn_0 | ~ready_0 | ~allow_drop_0;
   
    time_counter WAIT_TC_0 (
      .clk(clk),
      .inc(ready_0 & frame_tick & allow_drop_0),   // count frames only while READY
      .reset(wait_rst_0),
      .Count(wait_count_0)
    );
   
    // 1-frame pulse when count hits the target (apple 0)
    //assign chosen_fsm_0 = ready_0 & frame_tick & (wait_count_0 == wait_target_0);
   
   
    // ------------------------------------------------------------
    // Random fall timing (auto-chosen) - APPLE 1
    // (use a different mix so it doesn't mirror apple 0)
    // ------------------------------------------------------------
   
    wire [15:0] wait_target_sum_1;
    wire [15:0] rnd_delay_1;
    assign rnd_delay_1 = {9'b0, (rnd_stream[6:0] ^ rnd_stream[7:1])};   // mixed
   
    wire unused_cout_1, unused_ovfl_1;
    adder16 ADD_WAIT_1 (
      .A(rnd_delay_1),
      .B(16'd30),
      .cin(1'b0),
      .S(wait_target_sum_1),
      .cout(unused_cout_1),
      .ovfl(unused_ovfl_1)
    );
   
    // latch target when we spawn a new apple (apple 1)
    assign wait_target_next_1 = load_spawn_1 ? wait_target_sum_1 : wait_target_1;
   
    FDRE #(.INIT(1'b0)) WAIT_TGT_FF_1 [15:0] (
      .C(clk),
      .R(btnU),
      .CE(1'b1),
      .D(wait_target_next_1),
      .Q(wait_target_1)
    );
   
    // reset the wait counter whenever we are NOT in READY, or on spawn (apple 1)
    wire wait_rst_1;
    assign wait_rst_1 = btnU | load_spawn_1 | ~ready_1 | ~allow_drop_1;
   
    time_counter WAIT_TC_1 (
      .clk(clk),
      .inc(ready_1 & frame_tick & allow_drop_1),   // count frames only while READY
      .reset(wait_rst_1),
      .Count(wait_count_1)
    );
   
    // 1-frame pulse when count hits the target (apple 1)
    //assign chosen_fsm_1 = ready_1 & frame_tick & (wait_count_1 == wait_target_1);
   
   
    // ------------------------------------------------------------
    // FLASH blink visibility (per apple)
    // ------------------------------------------------------------
    wire flash_show_0;
    wire flash_show_1;
   
    assign flash_show_0 = flash_on_0 & blink_0;
    assign flash_show_1 = flash_on_1 & blink_1;

   
//---------------------------------------------------------------------------
//Apple green->red logic 1 apple //NO LONGER USING DIS ONE USE DA 2 APP ONE BELOW
//---------------------------------------------------------------------------

//    // 0..63 progress over ramp
//    wire [5:0] prog6;
//    assign prog6 = ramp_count[7:2];   // smoother ramp
   
//    wire [5:0] red6;
//    wire [5:0] grn6;
//    assign red6 = prog6;              // 0..63
//    assign grn6 = 6'd63 - prog6;      // 63..0
   
//    // Convert 6-bit -> 4-bit (VGA is 4 bits per channel)
//    wire [3:0] red4;
//    wire [3:0] grn4;
//    assign red4 = red6[5:2];
//    assign grn4 = grn6[5:2];
   
//    wire [11:0] ramp_color;
//    assign ramp_color = {red4, grn4, 4'b0000};
   
//---------------------------------------------------------------------------
// Apple green->red logic 2 apples
//---------------------------------------------------------------------------

    // game tick
    wire game_run;
    assign game_run = running;
   
    wire tick;
    assign tick = frame_tick & game_run;
   
    // slow ripening
    wire rip_tick;
    assign rip_tick = tick & (time_core[1:0] == 2'b00);
   
   
    //------------------------------------------------------------
    // Saturating increments
    //------------------------------------------------------------
   
    wire [5:0] rip0_inc;
    wire [5:0] rip1_inc;
    wire [5:0] rip2_inc;
    wire [5:0] rip3_inc;
    wire [5:0] rip4_inc;
    wire [5:0] rip5_inc;
    wire [5:0] rip6_inc;
    wire [5:0] rip7_inc;
   
    assign rip0_inc = (rip0 == 6'd63) ? 6'd63 : (rip0 + 6'd1);
    assign rip1_inc = (rip1 == 6'd63) ? 6'd63 : (rip1 + 6'd1);
    assign rip2_inc = (rip2 == 6'd63) ? 6'd63 : (rip2 + 6'd1);
    assign rip3_inc = (rip3 == 6'd63) ? 6'd63 : (rip3 + 6'd1);
    assign rip4_inc = (rip4 == 6'd63) ? 6'd63 : (rip4 + 6'd1);
    assign rip5_inc = (rip5 == 6'd63) ? 6'd63 : (rip5 + 6'd1);
    assign rip6_inc = (rip6 == 6'd63) ? 6'd63 : (rip6 + 6'd1);
    assign rip7_inc = (rip7 == 6'd63) ? 6'd63 : (rip7 + 6'd1);
   
   
    //------------------------------------------------------------
    // Detect start of FLASH for each apple
    //------------------------------------------------------------
   
    wire flash_on_d0;
    wire flash_on_d1;
   
    FDRE #(.INIT(1'b0)) FLASHD0_FF (.C(clk), .R(btnU), .CE(1'b1), .D(flash_on_0), .Q(flash_on_d0));
    FDRE #(.INIT(1'b0)) FLASHD1_FF (.C(clk), .R(btnU), .CE(1'b1), .D(flash_on_1), .Q(flash_on_d1));
   
    wire flash_start_0;
    wire flash_start_1;
   
    assign flash_start_0 = flash_on_0 & ~flash_on_d0;
    assign flash_start_1 = flash_on_1 & ~flash_on_d1;
   
   
    //------------------------------------------------------------
    // Hold slot green during flash
    //------------------------------------------------------------
   
    wire hold_slot0;
    wire hold_slot1;
    wire hold_slot2;
    wire hold_slot3;
    wire hold_slot4;
    wire hold_slot5;
    wire hold_slot6;
    wire hold_slot7;
   
    assign hold_slot0 = (flash_on_0 & (slot_use_0 == 3'd0)) | (flash_on_1 & (slot_use_1 == 3'd0));
    assign hold_slot1 = (flash_on_0 & (slot_use_0 == 3'd1)) | (flash_on_1 & (slot_use_1 == 3'd1));
    assign hold_slot2 = (flash_on_0 & (slot_use_0 == 3'd2)) | (flash_on_1 & (slot_use_1 == 3'd2));
    assign hold_slot3 = (flash_on_0 & (slot_use_0 == 3'd3)) | (flash_on_1 & (slot_use_1 == 3'd3));
    assign hold_slot4 = (flash_on_0 & (slot_use_0 == 3'd4)) | (flash_on_1 & (slot_use_1 == 3'd4));
    assign hold_slot5 = (flash_on_0 & (slot_use_0 == 3'd5)) | (flash_on_1 & (slot_use_1 == 3'd5));
    assign hold_slot6 = (flash_on_0 & (slot_use_0 == 3'd6)) | (flash_on_1 & (slot_use_1 == 3'd6));
    assign hold_slot7 = (flash_on_0 & (slot_use_0 == 3'd7)) | (flash_on_1 & (slot_use_1 == 3'd7));
   
   
    //------------------------------------------------------------
    // Reset ripeness when flash begins
    //------------------------------------------------------------
   
    wire rst_slot0;
    wire rst_slot1;
    wire rst_slot2;
    wire rst_slot3;
    wire rst_slot4;
    wire rst_slot5;
    wire rst_slot6;
    wire rst_slot7;
   
    assign rst_slot0 = (flash_start_0 & (slot_use_0 == 3'd0)) | (flash_start_1 & (slot_use_1 == 3'd0));
    assign rst_slot1 = (flash_start_0 & (slot_use_0 == 3'd1)) | (flash_start_1 & (slot_use_1 == 3'd1));
    assign rst_slot2 = (flash_start_0 & (slot_use_0 == 3'd2)) | (flash_start_1 & (slot_use_1 == 3'd2));
    assign rst_slot3 = (flash_start_0 & (slot_use_0 == 3'd3)) | (flash_start_1 & (slot_use_1 == 3'd3));
    assign rst_slot4 = (flash_start_0 & (slot_use_0 == 3'd4)) | (flash_start_1 & (slot_use_1 == 3'd4));
    assign rst_slot5 = (flash_start_0 & (slot_use_0 == 3'd5)) | (flash_start_1 & (slot_use_1 == 3'd5));
    assign rst_slot6 = (flash_start_0 & (slot_use_0 == 3'd6)) | (flash_start_1 & (slot_use_1 == 3'd6));
    assign rst_slot7 = (flash_start_0 & (slot_use_0 == 3'd7)) | (flash_start_1 & (slot_use_1 == 3'd7));
   
    //------------------------------------------------------------
    // Next ripeness state
    //------------------------------------------------------------
   
    wire [5:0] rip0;
    wire [5:0] rip1;
    wire [5:0] rip2;
    wire [5:0] rip3;
    wire [5:0] rip4;
    wire [5:0] rip5;
    wire [5:0] rip6;
    wire [5:0] rip7;
   
    wire [5:0] rip0_n;
    wire [5:0] rip1_n;
    wire [5:0] rip2_n;
    wire [5:0] rip3_n;
    wire [5:0] rip4_n;
    wire [5:0] rip5_n;
    wire [5:0] rip6_n;
    wire [5:0] rip7_n;
   
    assign rip0_n = btnU ? 6'd0 :
                    hold_slot0 ? 6'd0 :
                    rst_slot0  ? 6'd0 :
                    (rip_tick ? rip0_inc : rip0);
   
    assign rip1_n = btnU ? 6'd0 :
                    hold_slot1 ? 6'd0 :
                    rst_slot1  ? 6'd0 :
                    (rip_tick ? rip1_inc : rip1);
   
    assign rip2_n = btnU ? 6'd0 :
                    hold_slot2 ? 6'd0 :
                    rst_slot2  ? 6'd0 :
                    (rip_tick ? rip2_inc : rip2);
   
    assign rip3_n = btnU ? 6'd0 :
                    hold_slot3 ? 6'd0 :
                    rst_slot3  ? 6'd0 :
                    (rip_tick ? rip3_inc : rip3);
   
    assign rip4_n = btnU ? 6'd0 :
                    hold_slot4 ? 6'd0 :
                    rst_slot4  ? 6'd0 :
                    (rip_tick ? rip4_inc : rip4);
   
    assign rip5_n = btnU ? 6'd0 :
                    hold_slot5 ? 6'd0 :
                    rst_slot5  ? 6'd0 :
                    (rip_tick ? rip5_inc : rip5);
   
    assign rip6_n = btnU ? 6'd0 :
                    hold_slot6 ? 6'd0 :
                    rst_slot6  ? 6'd0 :
                    (rip_tick ? rip6_inc : rip6);
   
    assign rip7_n = btnU ? 6'd0 :
                    hold_slot7 ? 6'd0 :
                    rst_slot7  ? 6'd0 :
                    (rip_tick ? rip7_inc : rip7);
   
   
    //------------------------------------------------------------
    // Registers
    //------------------------------------------------------------
   
    FDRE #(.INIT(1'b0)) RIP0_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip0_n), .Q(rip0));
    FDRE #(.INIT(1'b0)) RIP1_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip1_n), .Q(rip1));
    FDRE #(.INIT(1'b0)) RIP2_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip2_n), .Q(rip2));
    FDRE #(.INIT(1'b0)) RIP3_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip3_n), .Q(rip3));
    FDRE #(.INIT(1'b0)) RIP4_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip4_n), .Q(rip4));
    FDRE #(.INIT(1'b0)) RIP5_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip5_n), .Q(rip5));
    FDRE #(.INIT(1'b0)) RIP6_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip6_n), .Q(rip6));
    FDRE #(.INIT(1'b0)) RIP7_FF [5:0] (.C(clk), .R(1'b0), .CE(1'b1), .D(rip7_n), .Q(rip7));

   
// ------------------------------------------------------------
// 6-bit ripeness -> 12-bit RGB per slot
// ------------------------------------------------------------

    // green component = 63 - ripeness
    wire [5:0] g0;
    wire [5:0] g1;
    wire [5:0] g2;
    wire [5:0] g3;
    wire [5:0] g4;
    wire [5:0] g5;
    wire [5:0] g6;
    wire [5:0] g7;
   
    assign g0 = 6'd63 - rip0;
    assign g1 = 6'd63 - rip1;
    assign g2 = 6'd63 - rip2;
    assign g3 = 6'd63 - rip3;
    assign g4 = 6'd63 - rip4;
    assign g5 = 6'd63 - rip5;
    assign g6 = 6'd63 - rip6;
    assign g7 = 6'd63 - rip7;
   
    // packed 12-bit colors per slot
    wire [11:0] col0;
    wire [11:0] col1;
    wire [11:0] col2;
    wire [11:0] col3;
    wire [11:0] col4;
    wire [11:0] col5;
    wire [11:0] col6;
    wire [11:0] col7;
   
    assign col0 = { rip0[5:2], g0[5:2], 4'b0000 };
    assign col1 = { rip1[5:2], g1[5:2], 4'b0000 };
    assign col2 = { rip2[5:2], g2[5:2], 4'b0000 };
    assign col3 = { rip3[5:2], g3[5:2], 4'b0000 };
    assign col4 = { rip4[5:2], g4[5:2], 4'b0000 };
    assign col5 = { rip5[5:2], g5[5:2], 4'b0000 };
    assign col6 = { rip6[5:2], g6[5:2], 4'b0000 };
    assign col7 = { rip7[5:2], g7[5:2], 4'b0000 };

       
//---------------------------------------------------------------------------
//// Falling Apple Logic CHECKPOINT 2!! (press btnD to drop)
////---------------------------------------------------------------------------
   
//    // 1) Frame tick: 1 pulse per VGA frame
//    // (hpx,vpx) are being generated on clk; (0,0) occurs once per frame
//    //declared above
   
//    // 2) Edge detect btnD to start the drop
//    //done in edge detector section above to keep consistancy :P
   
   
//    // 3) Apple X is fixed
//    wire [15:0] appleX;
//    assign appleX = 16'd320;  
   
//    // 4) Falling state FF
//    wire falling;
//    wire falling_next;
   
//    FDRE #(.INIT(1'b0)) FALLING_FF (.C(clk), .R(btnU), .CE(1'b1), .D(falling_next), .Q(falling));
   
//    // 5) Apple Y position FF
//    wire [15:0] appleY;
//    wire [15:0] appleY_next;
   
//    FDRE #(.INIT(1'b0)) APPLEY_FF [15:0] (.C(clk), .R(btnU), .CE(1'b1), .D(appleY_next), .Q(appleY));
   
//    // Stop falling when apple hits ground top (ground starts at vpx=432, apple is 10px tall)
//    wire hit_ground;
//    assign hit_ground = (appleY >= 16'd422);
   
//    assign falling_next =
//        btnU       ? 1'b0 :
//        d_pulse    ? 1'b1 :
//        hit_ground ? 1'b0 :
//        falling;
       
//    // Spawn height inside canopy
//    assign appleY_next =
//        btnU ? 16'd150 :
//        d_pulse ? 16'd150 : //respawn on each drop press
//        (frame_tick & falling & ~hit_ground) ? (appleY + 16'd1) :
//        appleY;
   
//    // 6) Apple pixel draw (10x10)
//    wire fallingApple;
//    assign fallingApple = active
//        & (hpx >= appleX) & (hpx < appleX + 16'd10)
//        & (vpx >= appleY) & (vpx < appleY + 16'd10);
       
//---------------------------------------------------------------------------
//COLOR LOGIC
//---------------------------------------------------------------------------

    // ------------------------------------------------------------
    // Per-apple selected ripeness
    // ------------------------------------------------------------
    wire [5:0] rip_sel_0;
    wire [5:0] rip_sel_1;
   
    assign rip_sel_0 =
        (slot_use_0 == 3'd0) ? rip0 :
        (slot_use_0 == 3'd1) ? rip1 :
        (slot_use_0 == 3'd2) ? rip2 :
        (slot_use_0 == 3'd3) ? rip3 :
        (slot_use_0 == 3'd4) ? rip4 :
        (slot_use_0 == 3'd5) ? rip5 :
        (slot_use_0 == 3'd6) ? rip6 :
                               rip7;
   
    assign rip_sel_1 =
        (slot_use_1 == 3'd0) ? rip0 :
        (slot_use_1 == 3'd1) ? rip1 :
        (slot_use_1 == 3'd2) ? rip2 :
        (slot_use_1 == 3'd3) ? rip3 :
        (slot_use_1 == 3'd4) ? rip4 :
        (slot_use_1 == 3'd5) ? rip5 :
        (slot_use_1 == 3'd6) ? rip6 :
                               rip7;

    wire [5:0] g_sel_0;
    wire [5:0] g_sel_1;
   
    assign g_sel_0 = 6'd63 - rip_sel_0;
    assign g_sel_1 = 6'd63 - rip_sel_1;
   
    wire [11:0] sel_grad_col_0;
    wire [11:0] sel_grad_col_1;
   
    assign sel_grad_col_0 = { rip_sel_0[5:2], g_sel_0[5:2], 4'b0000 };
    assign sel_grad_col_1 = { rip_sel_1[5:2], g_sel_1[5:2], 4'b0000 };
   
    wire [11:0] apple_color_0;
    wire [11:0] apple_color_1;
   
    assign apple_color_0 = is_golden_state_0 ? 12'hFF0 : sel_grad_col_0;
    assign apple_color_1 = is_golden_state_1 ? 12'hFF0 : sel_grad_col_1;
                             
    wire [11:0] falling_color;
    assign falling_color =
        fallingApple_0 ? apple_color_0 :
        fallingApple_1 ? apple_color_1 :
                         12'h000;
       
       
    // RGB COLOR LOGIC
    wire [11:0] rgb;
    assign rgb = ~active ? 12'h00C :
    border  ? 12'hC00 :
    player  ? 12'hCC0 :
   (fallingApple_0 | fallingApple_1) ? falling_color :
    a1_draw ? col0 :
    a2_draw ? col1 :
    a3_draw ? col2 :
    a4_draw ? col3 :
    a5_draw ? col4 :
    a6_draw ? col5 :
    a7_draw ? col6 :
    a8_draw ? col7 :
    leaves ? 12'h030 :
    trunk ? 12'h840 :
    ground  ? 12'h0F0 :  
              12'h009;  
     
    assign vgaRed = rgb[11:8];
    assign vgaGreen = rgb[7:4];
    assign vgaBlue = rgb[3:0];
       
endmodule