# Verification Plan: Matrix Multiplier Module (AXI4-Lite)

## 1. Scope & Objectives
- Verify AXI4-Lite slave interface protocol compliance
- Verify functional correctness of matrix multiply (C = A × B) across sizes/data patterns
- Verify control/status register behavior (start/stop/done/reset/error)
- Verify corner cases and error handling (misaligned access, back-to-back ops, reset mid-op)

**Assumptions** (update to match actual DUT): AXI4-Lite used for control/status + loading operand matrices into internal BRAM/regs; a `start` bit kicks off the MAC array; `done`/`irq` signal completion; matrix dims are fixed or configurable via register.

## 2. DUT Interfaces to Verify
- AXI4-Lite slave: AWADDR/AWVALID/AWREADY, WDATA/WSTRB, BRESP, ARADDR, RDATA, RRESP
- Register map: CTRL, STATUS, DIM_M/N/K (if configurable), matrix A/B write windows, result C read window, IRQ enable
- Optional: interrupt line, done flag polling path

## 3. Test Environment
- Directed SV testbench (or cocotb) with:
  - AXI4-Lite BFM/driver (write/read tasks)
  - Reference model (Python/C or SV function) computing expected C matrix
  - Scoreboard comparing DUT result registers/memory against reference
  - AXI protocol checker (use existing VIP/assertion IP if available rather than building from scratch)

## 4. Test Cases

### 4.1 Protocol-level (AXI4-Lite)
| ID | Test | Description |
|----|------|-------------|
| P1 | Basic write/read | Single write, single read to each register |
| P2 | Back-to-back access | Consecutive writes/reads with no gaps |
| P3 | Read-only write | Write to read-only register; expect SLVERR or ignored per spec |
| P4 | Write-only/reserved read | Read from write-only or reserved address |
| P5 | Unaligned access | Access at non-word-aligned address |
| P6 | WSTRB partial write | Partial byte writes via WSTRB |

### 4.2 Functional (Matrix Multiply)
| ID | Test | Description |
|----|------|-------------|
| F1 | Min size | Smallest supported matrix dimension |
| F2 | Max size | Maximum supported matrix dimension |
| F3 | Typical/random | Mid-size matrix, randomized data |
| F4 | All-zero | Zero matrix operands |
| F5 | Overflow/saturation | Max-value data; check wraparound vs saturation per spec |
| F6 | Identity multiply | One operand as identity matrix |
| F7 | Non-square | Non-square matrices (if supported) |

### 4.3 Control/Status
| ID | Test | Description |
|----|------|-------------|
| C1 | Start pulse | Verify single-cycle vs level-sensitive start behavior |
| C2 | Done polling | Poll STATUS.done after start until completion |
| C3 | Start-while-busy | Assert start again while busy; verify ignored/error response |
| C4 | Reset mid-op | Assert reset during active computation |
| C5 | IRQ assert/clear | Interrupt asserts on done and clears correctly (if IRQ exists) |

### 4.4 Error/Edge Cases
| ID | Test | Description |
|----|------|-------------|
| E1 | Invalid dimension | Configure dims of 0 or exceeding max (if configurable) |
| E2 | Stale result overwrite | Start new op without reading previous result |
| E3 | Reset defaults | Verify power-on/reset default register values |

## 5. Functional Coverage
- Matrix dims covered: min, max, mid, non-square (if applicable)
- Data value bins: zero, small, large/overflow, negative (if signed)
- Register access: each register written and read at least once
- start/done/reset sequencing cross-coverage
- AXI response types observed: OKAY, SLVERR (if applicable)

## 6. Checks / Assertions
- AXI handshake stability: VALID must not deassert before READY
- BRESP/RRESP correctness on illegal access
- `done` only asserts after `start`, clears appropriately
- Result matches reference model bit-exact

## 7. Pass/Fail Criteria
- All directed tests pass; scoreboard shows zero mismatches
- Functional coverage ≥ 95% on defined bins (100% on control/status)
- No protocol assertion failures across full regression

## 8. Open Items (fill in once DUT details are known)
- [ ] Actual register map / address offsets
- [ ] Matrix dimensions supported (fixed vs configurable range)
- [ ] Data width and signed/unsigned format
- [ ] Overflow behavior (saturate vs wrap)
- [ ] Interrupt presence and clear mechanism