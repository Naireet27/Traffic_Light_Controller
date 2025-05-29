//`default_nettype none

module Traffic_Controller (
    input wire clk,               // Clock signal
    input wire reset,             // Asynchronous reset (active high)
    input wire emergency,         // Emergency vehicle signal
    input wire [3:0] traffic_sensors, // [3]:EW2, [2]:EW1, [1]:NS2, [0]:NS1
    output reg [3:0] light,       // [3]:EW_Y, [2]:EW_G, [1]:NS_Y, [0]:NS_G
    output wire [7:0] state_timer_out // Expose internal timer for simulation/debug
);

    // Parameters for state durations (in clock cycles)
    parameter NS_GREEN_CYCLES = 100; // Duration for NS Green light
    parameter EW_GREEN_CYCLES = 60;  // Duration for EW Green light
    parameter YELLOW_CYCLES   = 20;  // Duration for Yellow light (both directions)
    parameter EMERGENCY_WAIT  = 5;   // Short wait during emergency transition if needed

    // State definition using parameters
    parameter [2:0] INIT            = 3'b000;
    parameter [2:0] NS_GREEN        = 3'b001;
    parameter [2:0] NS_YELLOW       = 3'b010;
    parameter [2:0] EW_GREEN        = 3'b011;
    parameter [2:0] EW_YELLOW       = 3'b100;
    parameter [2:0] EMERGENCY_TRANS = 3'b101; // Intermediate state for emergency
    parameter [2:0] EMERGENCY_GREEN = 3'b110; // State when emergency vehicle has priority (NS Green)
    
    reg [2:0] current_state, next_state; // State registers

    // Internal timer for state durations
    reg [7:0] state_timer; // Timer up to 256 cycles

    // Sensor logic (combinational)
    wire ns_sensor_active = traffic_sensors[1] | traffic_sensors[0];
    wire ew_sensor_active = traffic_sensors[3] | traffic_sensors[2];

    // State Register Logic (Clocked)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= INIT;
            state_timer <= 0; // Initialize timer on reset
        end else begin
            current_state <= next_state;
            
            if (next_state != current_state) begin // Reset timer on state change
                case (next_state)
                    NS_GREEN:        state_timer <= NS_GREEN_CYCLES -1; // Load duration (adjust for immediate decrement)
                    EW_GREEN:        state_timer <= EW_GREEN_CYCLES -1;
                    NS_YELLOW:       state_timer <= YELLOW_CYCLES -1;
                    EW_YELLOW:       state_timer <= YELLOW_CYCLES -1;
                    EMERGENCY_TRANS: state_timer <= EMERGENCY_WAIT -1; // Short delay if needed
                    EMERGENCY_GREEN: state_timer <= 1; // Keep timer active but short (or could be longer)
                    INIT:            state_timer <= 1; // Minimal time in init
                    default:         state_timer <= 1; // Default case
                endcase
            // Decrement timer if not changing state AND timer > 0
            end else if (state_timer != 0) begin
                 state_timer <= state_timer - 1;
            // If timer hits 0 and state doesn't change (e.g. NS_GREEN waiting for EW sensor), reload
            // This logic is handled by the state transition logic checking timer == 0
            
            end
            
        end
    end

    // Next State Logic (Combinational) 
    always @(*) begin // Use @(*) for combinational logic sensitivity list
        next_state = current_state; // Default: stay in current state

        // Emergency has highest priority
        if (emergency) begin
            case (current_state)
                NS_GREEN, EMERGENCY_GREEN: next_state = EMERGENCY_GREEN; // Already in or going to NS Green
                EW_GREEN:                  next_state = EW_YELLOW;       // Go to EW Yellow first
                EW_YELLOW:                 next_state = EMERGENCY_TRANS; // Transition through EW_YELLOW
                NS_YELLOW:                 next_state = EMERGENCY_GREEN; // Can go directly from NS_YELLOW
                EMERGENCY_TRANS:           next_state = EMERGENCY_GREEN; // Wait finished, go green
                INIT:                      next_state = EMERGENCY_GREEN; // Go directly if possible
                default:                   next_state = EMERGENCY_GREEN; // Go directly if possible
            endcase
        end else begin // Normal operation
            case (current_state)
                INIT: begin
                    next_state = NS_GREEN; // Start with NS Green after init/reset
                end
                NS_GREEN: begin
                    // If timer expired AND there's demand from EW
                    if (state_timer == 0 && ew_sensor_active) begin
                        next_state = NS_YELLOW;
                    end
                    
                end
                NS_YELLOW: begin
                    if (state_timer == 0) begin
                        next_state = EW_GREEN;
                    end
                end
                EW_GREEN: begin
                    // If timer expired AND there's demand from NS
                    if (state_timer == 0 && ns_sensor_active) begin
                        next_state = EW_YELLOW;
                    end
                    
                end
                EW_YELLOW: begin
                    if (state_timer == 0) begin
                        next_state = NS_GREEN;
                    end
                end
                EMERGENCY_TRANS: begin // This state should only be active during an emergency signal
                     // If emergency goes low *during* this state, decide where to go.
                     // Safest might be to proceed to NS_GREEN briefly then cycle normally.
                     // If emergency stays high, timer expiry moves to EMERGENCY_GREEN (handled above)
                     // For simplicity, assuming emergency stays high to reach here.
                     // If emergency becomes inactive:
                     // next_state = NS_GREEN; // Or EW_GREEN depending on prior state
                    if (state_timer == 0) begin // Should be triggered by emergency logic above
                         // This path likely won't be taken if 'emergency' is high
                         // If emergency went low exactly as timer hit 0, revert to normal cycle
                         next_state = NS_GREEN;
                     end

                end
                EMERGENCY_GREEN: begin // Was in emergency, now emergency signal is off
                     // Decide where to go next. Returning to NS_GREEN allows normal timeout/sensor check.
                     next_state = NS_GREEN;
                end
                default: begin
                    next_state = INIT; // Should not happen in normal operation
                end
            endcase
        end
    end

    // Output Logic (Combinational) - Using standard Verilog always block
    // light[3]:EW_Y, [2]:EW_G, [1]:NS_Y, [0]:NS_G
    always @(*) begin // Use @(*) for combinational logic sensitivity list
        case (current_state)
            NS_GREEN:        light = 4'b0001; // NS Green ON
            NS_YELLOW:       light = 4'b0010; // NS Yellow ON
            EW_GREEN:        light = 4'b0100; // EW Green ON
            EW_YELLOW:       light = 4'b1000; // EW Yellow ON
            EMERGENCY_TRANS: light = 4'b1000; // EW Yellow during transition to NS Green for emergency
            EMERGENCY_GREEN: light = 4'b0001; // NS Green during emergency
            INIT:            light = 4'b0000; // All Red initially
            default:         light = 4'b0000; // All Red if state is invalid (safety)
        endcase
    end

    // Assign internal timer to output port
    assign state_timer_out = state_timer;

endmodule
