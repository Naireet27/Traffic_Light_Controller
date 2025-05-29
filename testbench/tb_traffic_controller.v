//`default_nettype none
`timescale 1ns / 1ps // Define simulation time unit and precision

module tb_traffic_controller();

    // Testbench Signals
    reg clk;
    reg reset;
    reg emergency;
    reg [3:0] traffic_sensors; // [3]:EW2, [2]:EW1, [1]:NS2, [0]:NS1

    wire [3:0] light;      // [3]:EW_Y, [2]:EW_G, [1]:NS_Y, [0]:NS_G
    wire [7:0] state_timer_out; // Match DUT output width

    // Instantiate the traffic controller module
    Traffic_Controller uut (
        .clk(clk),
        .reset(reset),
        .emergency(emergency),
        .traffic_sensors(traffic_sensors),
        .light(light),
        .state_timer_out(state_timer_out)
    );

    // Clock generation (100 MHz)
    localparam CLK_PERIOD = 10; // ns
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end

    // Simulation Control and Stimulus
    initial begin
        // --- Setup ---
        $display("[%t ns] Starting Testbench...", $time);
        reset = 1'b1;   // Assert reset
        emergency = 1'b0;
        traffic_sensors = 4'b0000;
        repeat (3) @(posedge clk); // Hold reset for 3 cycles
        reset = 1'b0;   // De-assert reset
        $display("[%t ns] Reset Released.", $time);
        @(posedge clk); // Wait one cycle for reset to propagate

        // --- Scenario 1: NS Green (initial) -> EW Demand -> EW Green ---
        $display("[%t ns] Scenario 1: NS Green, then EW demand.", $time);
        traffic_sensors = 4'b0000; // No demand initially
        // Wait long enough for NS Green timer to potentially expire if there *were* demand
        #( (100 + 20 + 10) * CLK_PERIOD ); // Wait roughly NS_G + NS_Y duration + buffer
        $display("[%t ns] Activating EW sensors.", $time);
        traffic_sensors = 4'b1100; // Activate EW sensors
        // Wait long enough for transition: NS_G -> NS_Y -> EW_G
        #( (100 + 20 + 60 + 20 + 10) * CLK_PERIOD ); // Wait NS_G expiry + NS_Y + EW_G + EW_Y + buffer

        // --- Scenario 2: EW Green -> NS Demand -> NS Green ---
         $display("[%t ns] Scenario 2: EW Green, then NS demand.", $time);
        traffic_sensors = 4'b0011; // Activate NS sensors (EW sensors off)
        // Wait long enough for transition: EW_G -> EW_Y -> NS_G
        #( (60 + 20 + 100 + 20 + 10) * CLK_PERIOD ); // Wait EW_G expiry + EW_Y + NS_G + NS_Y + buffer

        // --- Scenario 3: Emergency Override during EW Green ---
        $display("[%t ns] Scenario 3: Emergency during EW Green.", $time);
        // First, force it back to EW Green
        traffic_sensors = 4'b1100; // EW demand
        #( (100 + 20 + 10) * CLK_PERIOD ); // Wait NS_G -> NS_Y
        $display("[%t ns] Should be EW Green now. Triggering Emergency.", $time);
        emergency = 1'b1; // <<<<< EMERGENCY ON
        // Wait long enough for emergency state to take effect and stay
        #( (20 + 100) * CLK_PERIOD ); // Wait Y + G duration
        $display("[%t ns] Emergency still active.", $time);
        emergency = 1'b0; // <<<<< EMERGENCY OFF
        traffic_sensors = 4'b0000; // Clear sensors
        $display("[%t ns] Emergency OFF. Resuming normal operation.", $time);
        // Wait long enough for it to cycle back based on sensors (or lack thereof)
        #( (100 + 20 + 60 + 20 + 10) * CLK_PERIOD );

        // --- Finish Simulation ---
        $display("[%t ns] Test scenarios complete. Finishing simulation.", $time);
        #50; // Extra delay before finishing
        $finish;
    end

    // Monitoring and VCD Dump
    initial begin
        // Setup VCD dump
        $dumpfile("traffic_dump.vcd");
        // Dump all signals in the testbench and the instantiated DUT (uut)
        $dumpvars(0, tb_traffic_controller);

        // Monitor key signals to console
        // Use $strobe for cleaner output at the end of the time step
        $strobe("[%t ns] State=%b Light(EW_Y,EW_G,NS_Y,NS_G)=%b Sensors(EW,NS)=%b Timer=%3d Emerg=%b",
         $time, uut.current_state, light, traffic_sensors[3:0], state_timer_out, emergency);
    end

endmodule
