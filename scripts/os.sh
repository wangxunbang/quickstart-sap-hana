# ------------------------------------------------------------------
#          RHEL or SLES
# ------------------------------------------------------------------

source /root/install/config.sh

isRHEL() {
    if [ "$MyOS" == "RHEL" ]; then
        echo 1
    elif [ "$MyOS" == "RHEL6" ]; then
    	echo 1
    elif [ "$MyOS" == "RHEL7" ]; then
    	echo 1
    else
      echo 0
    fi
}

isRHEL6() {
    if [ "$MyOS" == "RHEL6" ]; then
        echo 1
    else
      echo 0
    fi
}

isRHEL7() {
    if [ "$MyOS" == "RHEL7" ]; then
        echo 1
    else
      echo 0
    fi
}

isSLES() {
    if [ "$MyOS" == "SLES11SP4" ]; then
      echo 1
    elif [ "$MyOS" == "SLES12" ]; then
      echo 1
    elif [ "$MyOS" == "SLES12SP1" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES11SP4() {
    if [ "$MyOS" == "SLES11SP4" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12() {
    if [ "$MyOS" == "SLES12" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1() {
    if [ "$MyOS" == "SLES12SP1" ]; then
      echo 1
    else
      echo 0
    fi
}

issignal_check() {
    if [ -e "$SIG_FLAG_FILE" ]; then
      echo 1
    else
      echo 0
    fi
}
