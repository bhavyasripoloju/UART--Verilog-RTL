# UART IP Core (RTL Design & Verification)

A synthesizable, hardware-validated **UART (Universal Asynchronous Receiver-Transmitter)** serial communication protocol core implemented in **Verilog HDL**. This project includes independent transmitter and receiver modules, a configurable baud rate generator, and a comprehensive testbench for verification.

---

## 🚀 Features
* **Full-Duplex Communication:** Independent Transmitter (TX) and Receiver (RX) lines operating simultaneously.
* **Configurable Baud Rate:** Easily adjustable for standard rates (e.g., 9600, 115200) based on system clock frequency.
* **Standard Frame Format:** 
  * 1 Start Bit
  * 8 Data Bits
  * No Parity
  * 1 Stop Bit
* **Status Flags:** Read/Write ready indicators (`tx_busy`, `rx_ready`) for seamless integration with microcontrollers or FIFOs.
* **Fully Synthesizable:** Written in clean, vendor-agnostic RTL suitable for both FPGA and ASIC flows.

---

## 📂 Repository Structure
```text
├── rtl/
│   ├── uart_top.v     <img width="1600" height="900" alt="gobal" src="https://github.com/user-attachments/assets/fad365c6-58da-4559-aead-dd1154a84720" />
     # Top-level wrapper module
│   ├── uart_tx.v<img width="1600" height="900" alt="tx-module" src="https://github.com/user-attachments/assets/dadcdfd9-f9b7-40b1-9ed4-408946fffdf2" />
           # Transmitter module
│   ├── uart_rx.v <img width="1600" height="900" alt="rx_module" src="https://github.com/user-attachments/assets/dd5747b0-7997-40af-914b-1e971961997f" />
          # Receiver module
│   └── baud_gen.v <img width="1600" height="900" alt="baudrate_generator" src="https://github.com/user-attachments/assets/4e7330ba-3e29-44c8-94a9-11f7b85b4360" />
         # Baud rate generator (Clock divider)
├── sim/
│   ├── uart_tb.v           # Behavioral testbench
│   └── wave.vcd            # Simulated waveform output
└── README.md               # Documentation
