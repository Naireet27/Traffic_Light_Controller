**Overview**
This project implements a traffic light controller for a four-way intersection using Verilog HDL and simulates its behavior using a testbench. The traffic controller manages signals based on sensor inputs and handles emergency overrides.
Additionally, the traffic controller logic was re-implemented in C++ and tested on Tinkercad to demonstrate a purely software-based simulation of the system.

**Project Structure**
- Traffic_Controller.v
Verilog module implementing the traffic controller FSM logic.

- tb_traffic_controller.v
Verilog testbench for simulating the traffic controller module. Generates clock, reset, sensor inputs, and emergency signals.

- traffic_controller.cpp
C++ program simulating the traffic controller logic in software, runnable on Tinkercad or any C++ environment.

- traffic_dump.vcd
Waveform dump file generated during Verilog simulation for visualizing signals in GTKWave or other waveform viewers.

**Workflow**
1. Verilog Implementation & Simulation
  Developed the traffic controller FSM and supporting logic in Verilog. Created a testbench to simulate various traffic scenarios and emergency conditions. Ran the simulation in a Verilog simulator (ModelSim) and generated waveform files (traffic_dump.vcd). Used a waveform viewer to verify timing, light states, and emergency handling.

2. C++ Software Simulation
  Translated the Verilog FSM logic into a C++ program, preserving all timing and state transition behavior. Used Tinkercad’s online C++ environment to simulate the traffic controller as a purely software model. Verified that the C++ simulation produces the same logical output as the Verilog model.

**How to Run**
1. Verilog Simulation
- Open ModelSim.
- Compile the design files:
    vlog Traffic_Controller.v tb_traffic_controller.v
- Load the simulation and run:
    vsim tb_traffic_controller
  run 1000ns
- Use the waveform viewer in ModelSim to open and analyze signal waveforms.

2. C++ Simulation (Tinkercad)
- Open Tinkercad Circuits and create a new project.
- Copy and paste the contents of traffic_controller.cpp into the code editor.
- Run the simulation to observe the software model output in the serial console or terminal.

**Features**
Four-way traffic light control with North-South and East-West directions.
Traffic sensor inputs to detect vehicle demand on each road.
Emergency override that forces all signals to a safe flashing mode.
Timed green, yellow, and red light cycles.
Simulation of real-time behavior using both hardware description and software models.

**Notes**
This project is purely a simulation and does not interact with actual hardware.
The Verilog design focuses on timing and FSM correctness.
The C++ code mimics the Verilog FSM behavior for educational and prototyping purposes.

**License**
This project is provided as-is for educational use.
