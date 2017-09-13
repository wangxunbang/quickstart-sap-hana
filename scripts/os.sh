# ------------------------------------------------------------------
#          RHEL or SLES
# ------------------------------------------------------------------

source /root/install/config.sh

isRHEL() {
  if [[ "$MyOS" =~ "RHEL" ]]; then
    echo 1
  else
    echo 0
  fi
}

isSLES() {
  if [[ "$MyOS" =~ "SLES" ]]; then
    echo 1
  else
    echo 0
  fi
}


isRHEL6() {
  if [[ "$MyOS" =~ "RHEL6" ]]; then
    echo 1
  else
    echo 0
  fi
}

isRHEL7() {
  if [[ "$MyOS" =~ "RHEL7" ]]; then
    echo 1
  else
    echo 0
  fi
}


isSLES11SP4() {
    if [ "$MyOS" == "SLES11SP4HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12() {
    if [ "$MyOS" == "SLES12HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1() {
    if [ "$MyOS" == "SLES12SP1HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1SAP() {
    if [ "$MyOS" == "SLES12SP1SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP2SAP() {
    if [ "$MyOS" == "SLES12SP2SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1SAPBYOS() {
    if [ "$MyOS" == "SLES12SP1SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP2SAPBYOS() {
    if [ "$MyOS" == "SLES12SP2SAPBYOSHVM" ]; then
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
