# CAN2B - Evaluation Verilog IP Core

This repository provides a **limited evaluation version** of a CAN 2.0B compliant controller IP written in Verilog. It is designed for learning, simulation, and non-commercial testing.

> 🚫 AXI interface is not included in this version  
> ✅ Supports 11-bit Standard Identifier only  
> 🔒 Not for synthesis or production use

---

## 🚀 Features (Eval Version)
- CAN 2.0B compliant (standard ID only)
- Bit stuffing, CRC-15, arbitration logic
- Verilog RTL + simulation testbench
- Simulated using Vivado xsim / ModelSim

---

## 📁 Project Structure
```text
CAN2B_sbff/
├── rtl/               # Limited-feature Verilog source
├── tb/                # Self-checking testbench
├── doc/               # Eval-only datasheet
├── LICENSE            # Evaluation license
├── README.md
└── .gitignore
