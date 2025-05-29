// --- Pin Definitions ---
const int RESET_PIN = 2;
const int EMERGENCY_PIN = 3;
const int SENSOR_NS1_PIN = 4;
const int SENSOR_NS2_PIN = 5;
const int SENSOR_EW1_PIN = 6;
const int SENSOR_EW2_PIN = 7;

const int LIGHT_NS_G_PIN = 8;
const int LIGHT_NS_Y_PIN = 9;
const int LIGHT_EW_G_PIN = 10;
const int LIGHT_EW_Y_PIN = 11;

// --- State Durations (in Milliseconds) ---
// Adjusted from Verilog cycles for simulation visibility
const unsigned long NS_GREEN_MS = 10000; // 10 seconds
const unsigned long EW_GREEN_MS = 6000;  // 6 seconds
const unsigned long YELLOW_MS = 2000;    // 2 seconds
const unsigned long EMERGENCY_WAIT_MS = 500; // 0.5 seconds (for EW_YELLOW -> TRANSITION)
const unsigned long INIT_MS = 100;       // Short time in INIT state

// --- State Definitions ---
enum StateType {
  INIT,
  NS_GREEN,
  NS_YELLOW,
  EW_GREEN,
  EW_YELLOW,
  EMERGENCY_TRANS, 
  EMERGENCY_GREEN
};

// --- State Variables ---
StateType current_state = INIT;
StateType next_state = INIT; // Stores the calculated next state
unsigned long stateStartTime = 0; // Records when the current state started (using millis())

// --- Input Variables ---
bool reset_active = false;
bool emergency_active = false;
bool ns_sensor_active = false;
bool ew_sensor_active = false;

void readInputs();
void updateLights();
void printStateName(StateType state);

// --- Setup Function (runs once) ---
void setup() {
  Serial.begin(9600); // Initialize serial communication for debugging
  Serial.println("Traffic Light Controller Initializing...");

  // Configure Input Pins
  pinMode(RESET_PIN, INPUT_PULLUP);       // Active LOW reset
  pinMode(EMERGENCY_PIN, INPUT_PULLUP);    // Active LOW emergency
  pinMode(SENSOR_NS1_PIN, INPUT);        // Active HIGH sensor
  pinMode(SENSOR_NS2_PIN, INPUT);        // Active HIGH sensor
  pinMode(SENSOR_EW1_PIN, INPUT);        // Active HIGH sensor
  pinMode(SENSOR_EW2_PIN, INPUT);        // Active HIGH sensor

  // Configure Output Pins (Lights)
  pinMode(LIGHT_NS_G_PIN, OUTPUT);
  pinMode(LIGHT_NS_Y_PIN, OUTPUT);
  pinMode(LIGHT_EW_G_PIN, OUTPUT);
  pinMode(LIGHT_EW_Y_PIN, OUTPUT);

  // Initialize state and timer
  current_state = INIT;
  stateStartTime = millis();
  updateLights(); // Set initial light state (all off)

  Serial.println("Initialization Complete. Starting FSM.");
}

// --- Loop Function (runs repeatedly) ---
void loop() {
  // 1. Read Inputs
  readInputs();

  // 2. Check for Reset (Highest priority after reading inputs)
  if (reset_active) {
    Serial.println("RESET Activated!");
    current_state = INIT;
    stateStartTime = millis(); // Reset timer
    updateLights();
    // Optional: Add a small delay or wait for reset release
    delay(500); // Debounce/hold reset state briefly
    return; // Skip the rest of the loop iteration
  }

  // 3. Determine Next State Logic (Combinational equivalent)
  unsigned long currentTime = millis();
  unsigned long elapsedTime = currentTime - stateStartTime;
  unsigned long currentDuration = 0; // Duration required for the current state

  // Default: stay in the current state unless a condition changes it
  next_state = current_state;

  // --- Emergency Logic ---
  if (emergency_active) {
    // Emergency overrides normal operation
    switch (current_state) {
      case NS_GREEN:
      case EMERGENCY_GREEN:
        next_state = EMERGENCY_GREEN; // Already in NS Green or stay there
        break;
      case EW_GREEN:
        next_state = EW_YELLOW; // Go Yellow first
        currentDuration = YELLOW_MS; // Need yellow duration
        break;
      case EW_YELLOW:
        currentDuration = YELLOW_MS; // Check yellow duration
        if (elapsedTime >= currentDuration) {
             next_state = EMERGENCY_TRANS; // Go to transition state after yellow
             // Note: Verilog used EMERGENCY_WAIT for TRANS state duration.
        } else {
             next_state = EW_YELLOW; // Stay yellow until timer expires
        }
        break;
       case EMERGENCY_TRANS:
         currentDuration = EMERGENCY_WAIT_MS; // Wait state duration
         if (elapsedTime >= currentDuration) {
             next_state = EMERGENCY_GREEN; // Wait finished, go NS Green
         } else {
             next_state = EMERGENCY_TRANS; // Stay waiting
         }
         break;
      case NS_YELLOW:
        // Can go directly to NS Green from NS Yellow during emergency
        next_state = EMERGENCY_GREEN;
        break;
      case INIT:
      default: // Includes INIT
        next_state = EMERGENCY_GREEN; // Go directly to NS Green
        break;
    }
  } else {
    // --- Normal Operation Logic ---
    switch (current_state) {
      case INIT:
        currentDuration = INIT_MS;
        if (elapsedTime >= currentDuration) {
          next_state = NS_GREEN; // Default start after INIT
        }
        break;

      case NS_GREEN:
        currentDuration = NS_GREEN_MS;
        // Transition if timer expired AND there's demand from EW
        if (elapsedTime >= currentDuration && ew_sensor_active) {
          next_state = NS_YELLOW;
        }
        // Optional: Add max time logic even without EW demand here if needed
        // else if (elapsedTime >= MAX_NS_GREEN_MS) { next_state = NS_YELLOW; }
        break;

      case NS_YELLOW:
        currentDuration = YELLOW_MS;
        if (elapsedTime >= currentDuration) {
          next_state = EW_GREEN;
        }
        break;

      case EW_GREEN:
        currentDuration = EW_GREEN_MS;
        // Transition if timer expired AND there's demand from NS
        if (elapsedTime >= currentDuration && ns_sensor_active) {
          next_state = EW_YELLOW;
        }
        // Optional: Add max time logic even without NS demand here if needed
        // else if (elapsedTime >= MAX_EW_GREEN_MS) { next_state = EW_YELLOW; }
        break;

      case EW_YELLOW:
        currentDuration = YELLOW_MS;
        if (elapsedTime >= currentDuration) {
          next_state = NS_GREEN;
        }
        break;

      case EMERGENCY_TRANS:
         // Emergency ended during transition - revert to normal cycle safely
         // Go to NS_GREEN as a safe default after clearing
         next_state = NS_GREEN;
         Serial.println("Emergency ended during TRANS -> NS_GREEN");
        break;

      case EMERGENCY_GREEN:
        // Emergency signal just went low, transition out of emergency state
        next_state = NS_GREEN; // Return to normal NS Green
        Serial.println("Emergency ended -> NS_GREEN");
        break;

       default:
         // Should not happen
         next_state = INIT;
         break;
    }
  }

  // 4. State Transition Logic (Clocked equivalent)
  if (next_state != current_state) {
    Serial.print("State Change: ");
    printStateName(current_state);
    Serial.print(" -> ");
    printStateName(next_state);
    Serial.println();

    current_state = next_state;
    stateStartTime = currentTime; // Reset timer for the new state

    // Update lights immediately after state change
    updateLights();
  }  
}

// --- Helper Function: Read Inputs ---
void readInputs() {
  // Read reset pin (Active LOW)
  reset_active = (digitalRead(RESET_PIN) == LOW);

  // Read emergency pin (Active LOW)
  emergency_active = (digitalRead(EMERGENCY_PIN) == LOW);

  // Read sensors (Active HIGH) - Combine sensors for each direction
  ns_sensor_active = (digitalRead(SENSOR_NS1_PIN) == HIGH) || (digitalRead(SENSOR_NS2_PIN) == HIGH);
  ew_sensor_active = (digitalRead(SENSOR_EW1_PIN) == HIGH) || (digitalRead(SENSOR_EW2_PIN) == HIGH);
}

// --- Helper Function: Update Light Outputs ---
void updateLights() {
  // Turn all lights off first
  digitalWrite(LIGHT_NS_G_PIN, LOW);
  digitalWrite(LIGHT_NS_Y_PIN, LOW);
  digitalWrite(LIGHT_EW_G_PIN, LOW);
  digitalWrite(LIGHT_EW_Y_PIN, LOW);

  // Turn on the correct light(s) based on the current state
  switch (current_state) {
    case NS_GREEN:
    case EMERGENCY_GREEN: // NS Green light during emergency
      digitalWrite(LIGHT_NS_G_PIN, HIGH);
      break;
    case NS_YELLOW:
      digitalWrite(LIGHT_NS_Y_PIN, HIGH);
      break;
    case EW_GREEN:
      digitalWrite(LIGHT_EW_G_PIN, HIGH);
      break;
    case EW_YELLOW:
    case EMERGENCY_TRANS: // EW Yellow light during transition for emergency
       digitalWrite(LIGHT_EW_Y_PIN, HIGH);
       break;
    case INIT:
    default:
      // All lights remain OFF (handled by initial turn-off)
      break;
  }
}

// --- Helper Function: Print State Name ---
void printStateName(StateType state) {
  switch (state) {
    case INIT: Serial.print("INIT"); break;
    case NS_GREEN: Serial.print("NS_GREEN"); break;
    case NS_YELLOW: Serial.print("NS_YELLOW"); break;
    case EW_GREEN: Serial.print("EW_GREEN"); break;
    case EW_YELLOW: Serial.print("EW_YELLOW"); break;
    case EMERGENCY_TRANS: Serial.print("EMERGENCY_TRANS"); break;
    case EMERGENCY_GREEN: Serial.print("EMERGENCY_GREEN"); break;
    default: Serial.print("UNKNOWN"); break;
  }
}