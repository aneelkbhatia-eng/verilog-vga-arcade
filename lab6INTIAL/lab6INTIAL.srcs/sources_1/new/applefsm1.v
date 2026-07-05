`timescale 1ns / 1ps

module applefsm1 (
    input  clk,
    // game control
    input  go,        // start / running enable
    input  over,      // gameover (lives==0)
    // timing
    input  frame_tick,  // 1-cycle per frame
    // selection + events
    input  chosen,      //apple picked to fall
    input  caught,      // overlaps player while falling
    input  missed,      // hit ground while falling
    // counters done flags
    input  ramp_done,   // 240 frames done (green->red)
    input  flash_done,  // 2 sec done
    // latched type (from LFSR)
    input  make_golden, // 1 means next spawn is golden

    // outputs (control)
    output load_spawn,      // 1 cycle: latch X/type, reset y, reset counters
    output ramp_en,         // enable ramp counter 
    output ramp_rst,        // reset ramp counter
    output flash_en,        // enable flash counter
    output flash_rst,       // reset flash counter
    output ready,           // apple is eligible to be chosen
    output falling,         // apple should move down
    output do_score,        // pulse +1 point
    output do_life_down,    // pulse -1 life
    output do_life_up,      // pulse +1 life (golden reward)
    output flash_on,        // renderer should flash apple
    output is_golden_state  // renderer can color golden when true
);

    // ----------------------------
    // One-hot states
    // ----------------------------
    wire [10:0] st;
    wire [10:0] nxt;

    // STATES -> for reference <3
    // S0 IDLE
    // S1 LOAD
    // S2 RAMP
    // S3 READY
    // S4 FALL
    // S5 EVAL
    // S6 WIN
    // S7 LOSE
    // S8 REWARD
    // S9 FLASH
    // S10 GAMEOVER
   

    wire end_round;
    assign end_round = st[6] | st[7] | st[8]; // WIN/LOSE/REWARD end in FLASH
    
    wire is_golden;
    wire is_golden_next;
    
    assign is_golden_next = (st[1]) ? make_golden : is_golden;
    FDRE #(.INIT(1'b0)) GoldenFF (.C(clk), .R(1'b0), .CE(1'b1), .D(is_golden_next), .Q(is_golden));

    wire caught_lat, missed_lat;
    wire caught_lat_next, missed_lat_next;
    
    // Latch result ONLY when we transition FALL -> EVAL (i.e., st[4] & (caught|missed))
    assign caught_lat_next =
        (st[4] & (caught | missed)) ? caught :
        (st[1]) ? 1'b0 :  // clear on LOAD (new round)
        caught_lat;
    
    assign missed_lat_next =
        (st[4] & (caught | missed)) ? missed :
        (st[1]) ? 1'b0 :
        missed_lat;
    
    FDRE #(.INIT(1'b0)) CAUGHT_LAT_FF (.C(clk), .R(1'b0), .CE(1'b1), .D(caught_lat_next), .Q(caught_lat));
    FDRE #(.INIT(1'b0)) MISSED_LAT_FF (.C(clk), .R(1'b0), .CE(1'b1), .D(missed_lat_next), .Q(missed_lat));
    // ----------------------------
    // Next-state logic
    // ----------------------------

    // IDLE: wait for go
    assign nxt[0] = (~over) &( (st[0] & (~go)) | (st[9] & flash_done & ~go) );
    
    // LOAD: when go starts, or after FLASH completes (and not over) (choose green or golden path)
    assign nxt[1] = (~over) & ((st[0] & go) | (st[9] & flash_done & go) );

    // RAMP: after LOAD, run until ramp_done (green apple path), if golden, skip ramp
    // use "make_golden" sampled during LOAD by top-level latch
    // simplest: if make_golden==1 during LOAD, go straight to READY.
    //assign nxt[2] = (~over) & ((st[1] & ~make_golden) | (st[2] & ~ramp_done));
    
    assign nxt[2] = (~over) & ((st[1] & ~is_golden) | (st[2] & ~ramp_done));
    assign nxt[3] = (~over) & ( (st[2] & ramp_done) | (st[1] & is_golden) | (st[3] & ~chosen));
    
    
    // READY: after ramp_done                   OR                 golden spawn,       OR      wait for chosen
    //assign nxt[3] = (~over) & ( (st[2] & ramp_done) | (st[1] & make_golden) | (st[3] & ~chosen));

    // FALL: chosen while READY, continue until caught|missed
    assign nxt[4] = (~over) & ( (st[3] & chosen) | (st[4] & ~(caught | missed)) );

    // EVAL: one cycle after fall ends
    assign nxt[5] = (~over) & (st[4] & (caught | missed));

    // WIN / LOSE / REWARD: one-cycle bookkeeping
    // if caught and golden => REWARD, else if caught => WIN, else missed => LOSE
    assign nxt[6] = (~over) & (st[5] & caught_lat & ~is_golden);
    assign nxt[7] = (~over) & (st[5] & missed_lat);
    assign nxt[8] = (~over) & (st[5] & caught_lat & is_golden);


    // FLASH: flash for 2 sec then return to LOAD (if still go)
    assign nxt[9] = (~over) & ( (end_round) | (st[9] & ~flash_done));

    // If not go mid-game, fall back to IDLE-ish behavior (optional).
    // Simplest: if go drops, we just stop progressing because every nxt[...] is gated by go.
    
     // GAMEOVER
    assign nxt[10] = (st[10] | over);
 

    // ----------------------------
    // Outputs (all assign)
    // ----------------------------
    assign load_spawn   = st[1];

    assign ramp_rst     = st[1] | st[9];          // reset ramp on spawn and while flashing
    assign ramp_en      = st[2] & frame_tick;        // count frames only during RAMP

    assign flash_rst = st[1] | st[2] | st[3] | st[4] | st[5] | st[6] | st[7] | st[8];    
    assign flash_en     = st[9] & frame_tick;

    assign ready        = st[3];
    assign falling      = st[4];

    assign do_score     = st[6];    //non-golden catch
    assign do_life_down = st[7];    // miss
    assign do_life_up   = st[8];    //golden catch

    assign flash_on     = st[9];

    // "golden-ness" for rendering: during READY/FALL/EVAL/REWARD, use golden
    assign is_golden_state = is_golden & (st[3] | st[4] | st[5] | st[8]);

    // ----------------------------
    // State registers (FDRE only)
    // Power-up in IDLE
    // ----------------------------
    FDRE #(.INIT(1'b1)) st0 (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[0]), .Q(st[0]));
    FDRE #(.INIT(1'b0)) st1  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[1]),  .Q(st[1]));
    FDRE #(.INIT(1'b0)) st2  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[2]),  .Q(st[2]));
    FDRE #(.INIT(1'b0)) st3  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[3]),  .Q(st[3]));
    FDRE #(.INIT(1'b0)) st4  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[4]),  .Q(st[4]));
    FDRE #(.INIT(1'b0)) st5  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[5]),  .Q(st[5]));
    FDRE #(.INIT(1'b0)) st6  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[6]),  .Q(st[6]));
    FDRE #(.INIT(1'b0)) st7  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[7]),  .Q(st[7]));
    FDRE #(.INIT(1'b0)) st8  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[8]),  .Q(st[8]));
    FDRE #(.INIT(1'b0)) st9  (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[9]),  .Q(st[9]));
    FDRE #(.INIT(1'b0)) st10 (.C(clk), .R(1'b0), .CE(1'b1), .D(nxt[10]), .Q(st[10]));
    
endmodule
