# CAN Controller Documentation (v1.1)

## 🧩 Overview

This Verilog module implements a **CAN (Controller Area Network) controller**, compliant with ISO 11898-1. It includes:

- Bit Timing Unit
- Transmitter with Bit Stuffing and CRC-15
- Receiver with Bit Unstuffing and CRC-15 Checking
- Error Handling
- Control and Status Logic

---

## 📗 User Manual

### 🔌 Inputs & Outputs

| Signal         | Direction | Width | Description                                      |
|----------------|-----------|--------|--------------------------------------------------|
| `clk`          | Input     | 1      | Clock signal                                     |
| `rst`          | Input     | 1      | Asynchronous reset                               |
| `brp`          | Input     | 8      | Baud Rate Prescaler                              |
| `tseg1`        | Input     | 4      | Time Segment 1                                   |
| `tseg2`        | Input     | 4      | Time Segment 2                                   |
| `sjw`          | Input     | 4      | Synchronization Jump Width                       |
| `tx_start`     | Input     | 1      | Begin a transmission                             |
| `id`           | Input     | 29     | CAN frame identifier                             |
| `ide`          | Input     | 1      | Identifier extension (0 = standard, 1 = extended)|
| `rtr`          | Input     | 1      | Remote Transmission Request                      |
| `dlc`          | Input     | 4      | Data Length Code                                 |
| `data`         | Input     | 64     | Payload                                          |
| `ack_received` | Input     | 1      | ACK bit from the bus                             |
| `rx`           | Input     | 1      | Input from the CAN bus                           |
| `tx`           | Output    | 1      | Transmit bit to the CAN bus                      |
| `tx_done`      | Output    | 1      | Transmission completed                           |
| `busy`         | Output    | 1      | Transmitter is busy                              |
| `rx_data_valid`| Output    | 1      | A new frame has been received                    |
| `rx_data`      | Output    | 64     | Received CAN frame data                          |
| `rx_id`        | Output    | 29     | Received frame ID                                |
| `rx_dlc`       | Output    | 4      | Received frame DLC                               |
| `rx_ide`       | Output    | 1      | Received IDE bit                                 |
| `rx_rtr`       | Output    | 1      | Received RTR bit                                 |

---

### ✅ How to Use

1. **Setup Bit Timing**
2. **Transmit a Message**
3. **Receive a Message**

---

## 📙 Developer Guide

### 🔧 Architecture

```
CAN Controller
|
+-- bit_timing       -> Timing signals for CAN protocol
+-- can_tx           -> Bit stuffing and CRC-15 in transmit path
|   +-- bit_stuffing
|   +-- crc15
+-- can_rx           -> Bit unstuffing and CRC-15 checking
|   +-- bit_unstuffing
|   +-- crc15
+-- error_handling   -> Error states and reporting
+-- control logic    -> I/O coordination
```

---

### 🔍 Module Responsibilities

- **bit_timing.v**: Generates timing signals
- **can_tx.v**: Transmits frames with stuffing and CRC
- **can_rx.v**: Decodes frames, removes stuffing, checks CRC
- **bit_stuffing.v**: Stuff bits after 5 identical bits
- **bit_unstuffing.v**: Detect and remove stuffed bits
- **crc15.v**: CRC generation and checking (polynomial: `0x4599`)
- **error_handling.v**: Detect and handle all protocol-level errors

---

### ⚠️ Error Handling

| Error Type      | Detected by        | Flags Used              |
|------------------|--------------------|--------------------------|
| Bit Error        | can_tx             | `bit_error_tx`           |
| Stuff Error      | can_rx             | `stuff_error_rx`         |
| CRC Error        | can_rx/crc15       | `crc_error_rx`           |
| Form Error       | can_tx/can_rx      | `form_error_tx`, `form_error_rx` |
| ACK Error        | can_tx             | `ack_error_tx`           |
| Arbitration Lost | can_tx             | `arbitration_lost`       |

---

## 📦 Integration Guide

- Connect `tx`/`rx` to physical transceiver
- Include all RTL modules during synthesis
- Run testbenches for simulation validation

---

## 🔖 Version

**Version:** 1.1  
**Enhancements:**
- Added bit stuffing and unstuffing
- Added CRC-15 for standard compliance
