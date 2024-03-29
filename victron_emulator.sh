#!/bin/bash

SPLIT=0
if [ "$1" == "--split" ]; then
    SPLIT=1
    shift 1
fi

DEVICE=""
if [ -n "$1" ] && [ -e "$1" ]; then
    DEVICE="$1"
    stty -F $DEVICE 19200 cs8 -cstopb -parenb raw
fi

#decimal to ascii function
dec2ascii() {
  printf \\$(printf '%03o' $1)
}

#checksum calculate function
get_checksum() {
    INPUT="$1"
    LENGTH=${#INPUT}
        #length includes 0!
        LENGTH=$(($LENGTH - 1))
        CHECKSUM=0
        BS=0
        for pos in $(seq 0 $LENGTH)
        do
                #check for escaped character
                if [[ $BS -eq 0 ]]
                then
                        CHAR=${INPUT:$pos:1}
                else
                        CHAR=$CHAR${INPUT:$pos:1}
                        BS=0
                fi
                if [[ $CHAR = "\\" ]]
                then
                        BS=1;
                        continue;
                fi

                ASCII=$(ascii -t "$CHAR"|head -n1|cut -d' ' -f4)
                CHECKSUM=$(($CHECKSUM + $ASCII))
        done
    echo $CHECKSUM
}

#PARAMETER SET FOR BlueSolar 75/15
PID="0xA042"
FW="156"
SER="AA11111AAAA"
V="" # battery voltage (mV)
I="" # battery current (mA)
VPV="" # solar panel voltage (mV)
PPV="" # solar panel power (W)
CS="" # current state (of operation)
MPPT="" # MPPT tracker state
ERR="0"
LOAD=""
IL="0" # load current (mA)
H19="1234" # yield total (10 Wh)
H20="87" # yield today (10 Wh)
H21="222" # max power today (W)
H22="654" # yield yesterday (10 Wh)
H23="111" # maximum power yesterday (W)
HSDS="0" # day sequence number (0..364)

counter=0
while true; do
    counter=$((counter + 1))
    V=$(shuf -i 11500-14500 -n1)
    I=$(shuf -i 1000-8000 -n1)
    VPV=$(shuf -i 55500-70500 -n1)
    PPV=$((V * I * 104 / 100 / 1000000))
    CS=$(shuf -e 0 2 3 4 5 7 247 252 -n1)
    MPPT=$(shuf -i 0-2 -n1)
    LOAD=$(shuf -e OFF ON -n1)
    HSDS=$(date +%j)
    STRING1="\r\nPID\t$PID\r\nFW\t$FW\r\nSER#\t$SER\r\nV\t$V\r\nI\t$I\r\nVPV\t$VPV\r\nPPV\t$PPV\r\nCS\t$CS\r\nMPPT\t$MPPT\r\nERR\t$ERR"
    STRING2="\r\nLOAD\t$LOAD\r\nIL\t$IL\r\nH19\t$H19\r\nH20\t$H20\r\nH21\t$H21\r\nH22\t$H22\r\nH23\t$H23\r\nHSDS\t$HSDS"
    if [ $SPLIT -eq 1 ]; then
        if [ $((counter % 2)) -eq 0 ]; then
            STRING2=""
        else
            STRING1=""
        fi
    fi
    STRING="${STRING1}${STRING2}\r\nChecksum\t"

    CHECKSUM=$(get_checksum "$STRING")
    CHECKSUM=$(($CHECKSUM % 256))
    CHECKSUM=$((256 - $CHECKSUM))
    MISSING=$(dec2ascii $CHECKSUM)
    STRING=$STRING$MISSING
    CHECKSUM=$(get_checksum "$STRING")
    CHECKSUM=$(($CHECKSUM % 256))

    if [ $CHECKSUM -ne 0 ]; then
        echo -ne "\nERROR IN CHECKSUM, SKIP FRAME\n"
        continue
    fi

    if [ -n "$DEVICE" ]; then
        echo -ne "$STRING" >$DEVICE
    else
        echo -ne "$STRING"
    fi

    sleep 1
done
