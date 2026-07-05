`timescale 1ns / 1ps

module applefsmtb;

    // Inputs
    reg clk;
    reg go;
    reg over;
    reg frame_tick;
    reg chosen;
    reg caught;
    reg missed;
    reg ramp_done;
    reg flash_done;
    reg make_golden;

    // Outputs
    wire load_spawn;
    wire ready;
    wire falling;
    wire do_score;
    wire do_life_down;
    wire do_life_up;
    wire flash_on;

    // Instantiate your FSM
    apple_fsm_simple DUT (
        .clk(clk),
        .go(go),
        .over(over),
        .frame_tick(frame_tick),
        .chosen(chosen),
        .caught(caught),
        .missed(missed),
        .ramp_done(ramp_done),
        .flash_done(flash_done),
        .make_golden(make_golden),
        .load_spawn(load_spawn),
        .ramp_en(),        // unused
        .ramp_rst(),
        .flash_en(),
        .flash_rst(),
        .ready(ready),
        .falling(falling),
        .do_score(do_score),
        .do_life_down(do_life_down),
        .do_life_up(do_life_up),
        .flash_on(flash_on),
        .is_golden_state()
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Frame tick (simple slow pulse)
    initial begin
        frame_tick = 0;
        forever begin
            #40 frame_tick = 1;
            #10 frame_tick = 0;
        end
    end

    // Test sequence
    initial begin

        // Initialize everything
        go = 0;
        over = 0;
        chosen = 0;
        caught = 0;
        missed = 0;
        ramp_done = 0;
        flash_done = 0;
        make_golden = 0;

        #50;

        // -------------------------
        // Start game
        // -------------------------
        go = 1;
        #50;

        // -------------------------
        // GREEN APPLE -> CAUGHT
        // -------------------------
        make_golden = 0;

        @(posedge clk);
        ramp_done = 1;   // pretend 240 frames passed
        @(posedge clk);
        ramp_done = 0;

        @(posedge clk);
        chosen = 1;
        @(posedge clk);
        chosen = 0;

        @(posedge clk);
        caught = 1;
        @(posedge clk);
        caught = 0;

        @(posedge clk);
        flash_done = 1;
        @(posedge clk);
        flash_done = 0;

        #100;

        // -------------------------
        // GREEN APPLE -> MISSED
        // -------------------------
        make_golden = 0;

        @(posedge clk);
        ramp_done = 1;
        @(posedge clk);
        ramp_done = 0;

        @(posedge clk);
        chosen = 1;
        @(posedge clk);
        chosen = 0;

        @(posedge clk);
        missed = 1;
        @(posedge clk);
        missed = 0;

        @(posedge clk);
        flash_done = 1;
        @(posedge clk);
        flash_done = 0;

        #100;

        // -------------------------
        // GOLDEN APPLE -> CAUGHT
        // -------------------------
        make_golden = 1;

        @(posedge clk);
        chosen = 1;
        @(posedge clk);
        chosen = 0;

        @(posedge clk);
        caught = 1;
        @(posedge clk);
        caught = 0;

        @(posedge clk);
        flash_done = 1;
        @(posedge clk);
        flash_done = 0;

        #100;

        // -------------------------
        // GAME OVER
        // -------------------------
        over = 1;

        #100;

        $finish;
    end

endmodule