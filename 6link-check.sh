#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[0;33m'
CYN='\033[0;36m'
RST='\033[0m'

PASS="${GRN}OK${RST}"
FAIL="${RED}FAIL${RST}"
WARN="${YEL}WARN${RST}"

ERRORS=0
WARNINGS=0

echo ""
echo -e "${CYN}============================================${RST}"
echo -e "${CYN}  N6JET 6-Link Health Check${RST}"
echo -e "${CYN}  $(date -u '+%Y-%m-%d %H:%M:%S UTC')${RST}"
echo -e "${CYN}============================================${RST}"
echo ""

echo -e "${CYN}[1/6] Service Status${RST}"
echo "---------------------------------------------"

SERVICES=(
    "usrp-fanout:Fanout"
    "mmdvm-bridge-dmr:Leg 1 DMR MMDVM"
    "analog-bridge-dmr:Leg 1 DMR Analog"
    "mmdvm-bridge-ysf:Leg 2 YSF MMDVM"
    "analog-bridge-ysf:Leg 2 YSF Analog"
    "mmdvm-bridge-nxdn:Leg 3 NXDN MMDVM"
    "analog-bridge-nxdn:Leg 3 NXDN Analog"
    "mmdvm-bridge-p25:Leg 4 P25 MMDVM"
    "analog-bridge-p25:Leg 4 P25 Analog"
    "usrp2m17:Leg 5 M17 USRP2M17"
    "mmdvm-bridge-xlx:Leg 6 XLX MMDVM"
    "analog-bridge-xlx:Leg 6 XLX Analog"
)

for entry in "${SERVICES[@]}"; do
    SVC="${entry%%:*}"
    LABEL="${entry##*:}"
    STATE=$(systemctl is-active "$SVC" 2>/dev/null)
    if [ "$STATE" = "active" ]; then
        STARTED=$(systemctl show "$SVC" --property=ActiveEnterTimestamp --value 2>/dev/null)
        if [ -n "$STARTED" ]; then
            START_EPOCH=$(date -d "$STARTED" +%s 2>/dev/null || echo 0)
            NOW_EPOCH=$(date +%s)
            UPTIME_SEC=$((NOW_EPOCH - START_EPOCH))
            DAYS=$((UPTIME_SEC / 86400))
            HOURS=$(( (UPTIME_SEC % 86400) / 3600 ))
            MINS=$(( (UPTIME_SEC % 3600) / 60 ))
            UP_STR="${DAYS}d ${HOURS}h ${MINS}m"
        else
            UP_STR="unknown"
        fi
        printf "  %-25s [\e[32mOK\e[0m]  up %s\n" "$LABEL" "$UP_STR"
    else
        printf "  %-25s [\e[31mFAIL\e[0m]  %s\n" "$LABEL" "$STATE"
        ((ERRORS++))
    fi
done
echo ""

echo -e "${CYN}[2/6] Dependencies${RST}"
echo "---------------------------------------------"

DEPS=(
    "xlxd:XLX Reflector"
    "mrefd:M17 Reflector"
    "md380-emu:AMBE Transcoder"
    "YSFReflector:YSF Reflector"
    "NXDNReflector:NXDN Reflector"
    "p25reflector:P25 Reflector"
)

for entry in "${DEPS[@]}"; do
    SVC="${entry%%:*}"
    LABEL="${entry##*:}"
    STATE=$(systemctl is-active "$SVC" 2>/dev/null)
    if [ "$STATE" = "active" ]; then
        printf "  %-25s [\e[32mOK\e[0m]\n" "$LABEL"
    else
        printf "  %-25s [\e[31mFAIL\e[0m]  %s\n" "$LABEL" "$STATE"
        ((ERRORS++))
    fi
done
echo ""

echo -e "${CYN}[3/6] Port Check${RST}"
echo "---------------------------------------------"

for PORT in 34001 34002 34003 34004 34005 34006; do
    if ss -uln | grep -q ":${PORT} " 2>/dev/null; then
        printf "  Fanout :%s            [\e[32mOK\e[0m]\n" "$PORT"
    else
        printf "  Fanout :%s            [\e[31mFAIL\e[0m]  not listening\n" "$PORT"
        ((ERRORS++))
    fi
done

if ss -uln | grep -q ":2470 " 2>/dev/null; then
    printf "  md380-emu :2470        [\e[32mOK\e[0m]\n"
else
    printf "  md380-emu :2470        [\e[31mFAIL\e[0m]  not listening\n"
    ((ERRORS++))
fi

if ss -uap 2>/dev/null | grep -q ":62032"; then
    printf "  TGIF :62031/62032      [\e[32mOK\e[0m]\n"
else
    printf "  TGIF :62031/62032      [\e[31mFAIL\e[0m]  no connection\n"
    ((ERRORS++))
fi

if ss -uap 2>/dev/null | grep -q ":62034"; then
    printf "  XLXJET :62030/62034    [\e[32mOK\e[0m]\n"
else
    printf "  XLXJET :62030/62034    [\e[31mFAIL\e[0m]  no connection\n"
    ((ERRORS++))
fi
echo ""

echo -e "${CYN}[4/6] Recent Activity${RST}"
echo "---------------------------------------------"

LOGDATE=$(date -u '+%Y-%m-%d')
for PAIR in "DMR Bridge:/var/log/dvswitch/DMR-Bridge-${LOGDATE}.log" "YSF Bridge:/var/log/dvswitch/YSF-Bridge-${LOGDATE}.log" "NXDN Bridge:/var/log/dvswitch/NXDN-Bridge-${LOGDATE}.log" "P25 Bridge:/var/log/dvswitch/P25-Bridge-${LOGDATE}.log" "XLX Bridge:/var/log/dvswitch/XLX-Bridge-${LOGDATE}.log"; do
    LABEL="${PAIR%%:*}"
    LOGFILE="${PAIR##*:}"
    if [ -f "$LOGFILE" ]; then
        LINES=$(wc -l < "$LOGFILE")
        LAST=$(tail -1 "$LOGFILE" 2>/dev/null | grep -oP '^\S+ \S+' | head -1)
        printf "  %-20s %s lines, last: %s\n" "$LABEL" "$LINES" "${LAST:-unknown}"
    else
        printf "  %-20s [\e[33mWARN\e[0m] no log file\n" "$LABEL"
        ((WARNINGS++))
    fi
done
echo ""

echo -e "${CYN}[5/6] Recent Errors (last 30 min)${RST}"
echo "---------------------------------------------"

ERR_COUNT=0
for SVC in usrp-fanout mmdvm-bridge-dmr analog-bridge-dmr mmdvm-bridge-ysf analog-bridge-ysf mmdvm-bridge-nxdn analog-bridge-nxdn mmdvm-bridge-p25 analog-bridge-p25 usrp2m17 mmdvm-bridge-xlx analog-bridge-xlx; do
    ERRS=$(journalctl -u "$SVC" --since "30 min ago" -p err --no-pager 2>/dev/null | grep -v "^--" | wc -l)
    if [ "$ERRS" -gt 0 ]; then
        printf "  %-30s \e[31m%d errors\e[0m\n" "$SVC" "$ERRS"
        ((ERR_COUNT += ERRS))
    fi
done
if [ "$ERR_COUNT" -eq 0 ]; then
    echo -e "  \e[32mNo errors in last 30 minutes\e[0m"
fi
echo ""

echo -e "${CYN}[6/6] Restart Counts${RST}"
echo "---------------------------------------------"

NO_RESTARTS=true
for entry in "${SERVICES[@]}"; do
    SVC="${entry%%:*}"
    LABEL="${entry##*:}"
    RESTARTS=$(systemctl show "$SVC" --property=NRestarts --value 2>/dev/null || echo "0")
    if [ "$RESTARTS" -gt 0 ] 2>/dev/null; then
        printf "  %-25s \e[33m%s restarts\e[0m\n" "$LABEL" "$RESTARTS"
        ((WARNINGS++))
        NO_RESTARTS=false
    fi
done
if $NO_RESTARTS; then
    echo -e "  \e[32mNo restarts detected\e[0m"
fi
echo ""

echo -e "${CYN}============================================${RST}"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "  \e[32m6-Link is HEALTHY — all systems go\e[0m"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "  \e[33m6-Link is UP with $WARNINGS warning(s)\e[0m"
else
    echo -e "  \e[31m6-Link has $ERRORS ERROR(s) and $WARNINGS warning(s)\e[0m"
fi
echo -e "${CYN}============================================${RST}"
echo ""
