#!/bin/sh
# Economy v5: recalibrate from Rebirth 2 (Suburbs x2 work, saving warning), then every check
cd "$(dirname "$0")"
python3 v5.py calibrate 1 > v5_calib.log 2>&1
python3 v5_value.py > v5_value.log 2>&1
python3 v5_checks.py > v5_checks.log 2>&1
python3 v5_market.py > v5_market.log 2>&1
echo DONE >> v5_market.log
