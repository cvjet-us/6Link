# N6JET 6-Link

A digital voice bridge that connects six amateur radio digital modes — DMR, YSF, NXDN, P25, M17, and D-STAR — so a transmission on any one mode is heard simultaneously on all the others.

**License:** GNU General Public License v2 (GPL-2.0)

Here it is. Give it a try. Modify it if you like. Share it with others. No support, no warranty, no guarantees.

73 — N6JET

---

## How it works

Each mode has its own reflector or gateway service running on a single Linux host. Each service is paired with a bridge process that converts the mode's native protocol into a common PCM audio stream over USRP. A central Python relay (`usrp-fanout.py`) receives audio from any one leg and re-broadcasts it to the other five.

The result: a single key-up reaches everyone on all six modes at once.

```
  DMR (TGIF 95110)         ──┐
  YSF (Reflector 95110)    ──┤
  NXDN (Reflector 9511)    ──┤── USRP ──► usrp-fanout.py ──► all other legs
  P25 (Reflector 9511)     ──┤
  M17 (M17-JET, module Q)  ──┤
  D-STAR (XLXJET, module Q)──┘
```

The entire stack runs as systemd services on a single host. No external network hops between legs — only the user-to-reflector path traverses the public internet.

---

## How to connect

Point your hotspot or repeater at the appropriate endpoint:

| Mode | Endpoint |
|------|----------|
| DMR | TGIF talkgroup 95110 |
| YSF | Reflector 95110 |
| NXDN | Reflector 9511 |
| P25 | Reflector 9511 |
| M17 | M17-JET, module Q |
| D-STAR | XLXJET, module Q (via DPlus / DExtra / DCS / MMDVM) |

Works with WPSD, Pi-Star, SharkRF OpenSpot, or any hotspot/repeater that can connect to these services.

---

## Architecture

The 6-Link runs on a Hetzner VPS (Ubuntu 24.04). Each leg consists of:

| Leg | Mode | Reflector/Service | Bridge Pair | Fanout Ports |
|-----|------|-------------------|-------------|--------------|
| 1 | DMR | TGIF (TG 95110) | MMDVM_Bridge + Analog_Bridge | 34001 ↔ 32001 |
| 2 | YSF | YSF Reflector 95110 | MMDVM_Bridge + Analog_Bridge | 34002 ↔ 32002 |
| 3 | NXDN | NXDN Reflector 9511 | MMDVM_Bridge + Analog_Bridge | 34003 ↔ 32003 |
| 4 | P25 | P25 Reflector 9511 | MMDVM_Bridge + Analog_Bridge | 34004 ↔ 32004 |
| 5 | M17 | M17JET (mrefd) module Q | usrp2m17 (USRP-native) | 34170 ↔ 32170 |
| 6 | D-STAR | XLXJET (xlxd) module Q | MMDVM_Bridge + Analog_Bridge | 34006 ↔ 32006 |

AMBE transcoding is handled by an on-host md380-emu instance (port 2470).

---

## Files

| File | Description |
|------|-------------|
| usrp-fanout.py | Central USRP audio relay — receives from any leg, fans out to the other five |
| 6link-check.sh | Health check script — checks all services, dependencies, ports, logs, errors, and restarts |
| n6jet-6link.html | Public-facing web page describing the 6-Link and how to connect |
| n6jet-6link-logo.png | 6-Link logo graphic |
| n6jet_6link_architecture.jpg | Architecture diagram |

---

## Services (systemd)

### Bridge services (12)
- usrp-fanout
- mmdvm-bridge-dmr / analog-bridge-dmr
- mmdvm-bridge-ysf / analog-bridge-ysf
- mmdvm-bridge-nxdn / analog-bridge-nxdn
- mmdvm-bridge-p25 / analog-bridge-p25
- usrp2m17
- mmdvm-bridge-xlx / analog-bridge-xlx

### Dependencies (6)
- xlxd (XLX Reflector)
- mrefd (M17 Reflector)
- md380-emu (AMBE Transcoder)
- YSFReflector
- NXDNReflector
- p25reflector

---

## Health check

Run the health check to verify all 6-Link components are operational:

```bash
/opt/dvswitch-relay/6link-check.sh
```

Checks:
1. Service status and uptime for all 12 bridge services
2. Dependency status for all 6 reflectors/transcoders
3. Port check for all fanout ports and AMBE transcoder
4. Recent activity from bridge logs
5. Error count from the last 30 minutes
6. Service restart counts

---

## History

The 6-Link started as a quad-link (4 modes), grew to a quint-link (5 modes), and reached its current 6-mode configuration bridging DMR, YSF, NXDN, P25, M17, and D-STAR.

---

## Part of n6jet.com

- **XLXJET** — D-Star gateway reflector (port 42000)
- **URFJET** — Multi-protocol URF reflector (port 42000)
- **M17JET** — M17 reflector (port 17000)
- **YSFJET / YSF 95110** — Fusion gateway reflector (port 42002)

73 — N6JET
