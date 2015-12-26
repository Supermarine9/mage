################################################################################
#                                    Mage
#         A Distributed Administration Utility for Linux/Unix Systems
#
#                                 Version 1.0
#
# Copyright (C) 2015  Wesley Dewsnup
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA or see
# http://www.gnu.org/licenses/
################################################################################

#!/usr/bin/env bash

################################################################################
# Declare Variables #
#####################
BOLD=$( tput bold )
NORMAL=$( tput sgr0 )
HOME=$( dirname $( readlink -f "$0" ) )
OUTPUT_D=scripts
COPY_D=/tmp/mage
LOG=logs
PEONLIST=peons
DEFAULT_CSV=servers_list.csv
DEFAULT_USER=root
################################################################################

################################################################################
# DEPENDENCIES FUNCTIONS #
##########################

# Check if running as root
##########################
check_root()
{
  if [[ $EUID -ne 0 ]]; then
    echo "${BOLD}Mage must be run as root${NORMAL}"
    exit 1
  fi
}

# Check Apps
############
check_apps()
{
  DEPEND1=dos2unix
  DEPEND2=sshpass
  DEFAULT_ANSWER=yes
  if [ ! -f /usr/bin/$DEPEND1 ] && [ ! -f /usr/bin/$DEPEND2 ]; then
    DEPENDENCY="[ ! -f /usr/bin/$DEPEND1 -a ! -f /usr/bin/$DEPEND2 ]"
    DEP="$DEPEND1 and $DEPEND2"
    INSTALL_DEP="$DEPEND1 $DEPEND2"
  elif [ ! -f /usr/bin/$DEPEND1 ]; then
    DEPENDENCY="[ ! -f /usr/bin/$DEPEND1 ]"
    DEP=$DEPEND1
    INSTALL_DEP=$DEPEND1
  elif [ ! -f /usr/bin/$DEPEND2 ]; then
    DEPENDENCY="[ ! -f /usr/bin/$DEPEND2 ]"
    DEP=$DEPEND2
    INSTALL_DEP=$DEPEND2
  else
    return
  fi
  while $DEPENDENCY; do
    echo -e "${BOLD}Mage has dependency on $DEP${NORMAL}\n"
    while [[ $ANSWER != @([yY][eE][sS]|[yY]) ]]; do
      read -e -p "${BOLD}Would you like to install $DEP now?${NORMAL} [Y/n]: " ANSWER
      ANSWER=${ANSWER:-$DEFAULT_ANSWER}
      if [[ $ANSWER =~ ^([nN][oO]|[nN])$ ]]; then
        exit 0
      fi
    done
    if [ -f /etc/redhat-release ]; then
      echo -e "\nyum -y install $INSTALL_DEP\n"
      yum -y install $INSTALL_DEP
    elif [ -f /etc/debian_version ]; then
      echo -e "\napt-get update && apt-get -y install $INSTALL_DEP\n"
      apt-get update && apt-get -y install $INSTALL_DEP
    elif [ -f /etc/SuSE-release ]; then
      echo -e "\nzypper -n in $INSTALL_DEP\n"
      zypper -n in $INSTALL_DEP
    else
      echo -e "\n${BOLD}Unable to determine package manager. Install $DEP and rerun Mage.${NORMAL}\n"
      exit 1
    fi
    if $DEPENDENCY; then
      ANSWER=null
    fi
    any_key
  done
}

# Check for required folders
############################
check_folders()
{
  mkdir -p $HOME/$OUTPUT_D
  mkdir -p $HOME/$LOG
}

# Check logic
#############
check()
{
  check_root
  check_apps
  check_folders
}
################################################################################

################################################################################
# MAIN FUNCTIONS #
##################

# Header
########
header()
{
  clear
  TITLE="~= Mage =~"
  DESCRIPTION="A Distributed Administration Utility for Linux/Unix Systems"
  VERSION="Version 1.0"
  printf "%*s\n" $(( ( $(echo $TITLE | wc -c ) + 80 ) / 2 )) "${BOLD}$TITLE${NORMAL}"
  printf "%*s\n" $(( ( $(echo $DESCRIPTION | wc -c ) + 80 ) / 2 )) "${BOLD}$DESCRIPTION${NORMAL}"
  echo
  printf "%*s\n" $(( ( $(echo $VERSION | wc -c ) + 80 ) / 2 )) "${BOLD}$VERSION${NORMAL}"
  echo -e "\n"
}

# Copyright
###########
copyright()
{
read -d '' COPYRIGHT <<- EOF
${BOLD}Copyright (C) 2015  Wesley Dewsnup${NORMAL}

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but ${BOLD}WITHOUT ANY WARRANTY${NORMAL}; without even the implied warranty of
${BOLD}MERCHANTABILITY${NORMAL} or ${BOLD}FITNESS FOR A PARTICULAR PURPOSE${NORMAL}.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA or see
http://www.gnu.org/licenses/
EOF
  echo -e "$COPYRIGHT\n"
}

# Accept licence
################
accept()
{
  while [[ $ACCEPT != @([sS]|[cC]) ]]; do
    header
    copyright
    read -e -p "'L' view full license, 'Q' to quit, 'S' for setup, or 'Enter' to continue: " ACCEPT
    ACCEPT=${ACCEPT:-C}
    if [[ $ACCEPT =~ ^([lL])$ ]]; then
      less $HOME/LICENSE
    elif [[ $ACCEPT =~ ^([qQ])$ ]]; then
      clear
      exit 1
    fi
  done
  if [[ $ACCEPT =~ ^([sS])$ ]]; then
    configure
  elif [[ $ACCEPT =~ ^([cC])$ ]]; then
    if [ ! -f "$HOME/$PEONLIST" ]; then
      configure
    fi
  fi
}

# CSV
#####
csv()
{
  read -e -p "List of end target servers to be actioned upon [$DEFAULT_CSV]: " CSV
  CSV=${CSV:-$DEFAULT_CSV}
}

# Connection type
#################
connection_type()
{
  echo -e "\nConnect to servers via SSH Key or Username / Password?\n"
  PS3='Enter selection: '
  OPTIONS=("SSH Key" "Username / Password")
  select OPT in "${OPTIONS[@]}"; do
    case $OPT in
      "SSH Key")
        USER=null
        break
        ;;
      "Username / Password")
        echo
        user
        break
        ;;
      *) echo Invalid Selection;;
    esac
  done
}

# User
######
user()
{
  read -e -p "Enter username [$DEFAULT_USER]: " USER
  USER=${USER:-$DEFAULT_USER}
  password
}

# Password
##########
password()
{
  PASSWORD=null
  while [[ $PASSWORD != $PASSWORD2 ]]; do
    read -s -p "Enter password: " PASSWORD
    echo
    read -s -p "Re-enter password: " PASSWORD2
    echo
    if [ $PASSWORD != $PASSWORD2 ]; then
      echo -e "\n${BOLD}Passwords do not match, re-enter password...${NORMAL}\n"
    fi
  done
}

# List
######
list()
{
  header
  echo -e "Select the command to run:\n"
  PS3='Enter selection: '
  OPTIONS=("OS Update" "Check System Uptime" "Reboot" "Custom Command" "Abort")
  select OPT in "${OPTIONS[@]}"; do
    case $OPT in
      "OS Update")
        SELECTION='OS Update'
        ACTION="if [ -f /etc/redhat-release ]; then yum -y upgrade; elif [ -f /etc/debian_version ]; then apt-get update && apt-get -y dist-upgrade; elif [ -f /etc/SuSE-release ]; then zypper -n update; elif [ freebsd-version ]; then freebsd-update --not-running-from-cron fetch install && pkg upgrade -y && portsnap update && portmaster -G --no-confirm -a; else echo 'Unable to perform update - Unable to determine package manager'; exit 1; fi"
        break
        ;;
      "Check System Uptime")
        SELECTION='Check System Uptime'
        ACTION='uptime'
        break
        ;;
      "Reboot")
        SELECTION='Reboot'
        ACTION='reboot'
        break
        ;;
      "Custom Command")
        custom
        SELECTION="Custom Command ( ${BOLD}$ACTION${NORMAL} )"
        break
        ;;
      "Abort")
        clear
        exit 1
        ;;
      *) echo Invalid Selection;;
    esac
  done
}

# Custom
########
custom()
{
  while [[ $VERIFY != @([yY][eE][sS]|[yY]) ]]; do
    header
    echo -e "${BOLD}Custom Command${NORMAL}\n"
    echo -e "\n${BOLD}Note: sudo is automatically added when utilizing any account other than 'root'${NORMAL}\n"
    echo -e "${BOLD}Ensure $USER is allowed in /etc/sudoers to perform administrative actions${NORMAL}\n"
    read -e -p "Enter the command to run: " ACTION
    echo -e "\nYou entered ( ${BOLD}$ACTION${NORMAL} )\n\n"
    verify
  done
  unset VERIFY
}

# Peon script
#############
peon_script()
{
  SCRIPT=cast.sh
  SUDO="echo '$PASSWORD' | sudo -Sk"
cat > $HOME/$OUTPUT_D/$SCRIPT << EOF
#!/usr/bin/env bash

PEON=\$( hostname | cut -c1-3 | tr -s [a-z] [A-Z] )

for SERVERS in \$( grep ^\$PEON $COPY_D/$CSV ); do
  SERVER=\$( echo \$SERVERS | awk -F ',' '{ print \$3 }' )
  IPADDR=\$( echo \$SERVERS | awk -F ',' '{ print \$2 }' )
  echo \$SERVER \$IPADDR > $COPY_D/$LOG/\$SERVER.log
  echo \$SERVER \$IPADDR > $COPY_D/$LOG/\$SERVER.err
EOF
  if [ $USER = null ]; then
    echo -e "  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root \$IPADDR -t -t '$ACTION' 1>>$COPY_D/$LOG/\$SERVER.log 2>>$COPY_D/$LOG/\$SERVER.err &" >> $HOME/$OUTPUT_D/$SCRIPT
  elif [ $USER = root ]; then
    echo -e "  /usr/bin/sshpass -p '$PASSWORD' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l $USER \$IPADDR -t -t '$ACTION' 1>>$COPY_D/$LOG/\$SERVER.log 2>>$COPY_D/$LOG/\$SERVER.err &" >> $HOME/$OUTPUT_D/$SCRIPT
  elif [ $USER != null ] && [ $USER != root ] && [ "$SELECTION" = "OS Update" ]; then
    echo -e "  /usr/bin/sshpass -p '$PASSWORD' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l $USER \$IPADDR -t -t '$ACTION' 1>>$COPY_D/$LOG/\$SERVER.log 2>>$COPY_D/$LOG/\$SERVER.err &" >> $HOME/$OUTPUT_D/$SCRIPT
    sed -i "10s,&&,\&\& $SUDO,g" $HOME/$OUTPUT_D/$SCRIPT
    sed -i "10s,then,then $SUDO,g" $HOME/$OUTPUT_D/$SCRIPT
  else
    echo -e "  /usr/bin/sshpass -p '$PASSWORD' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l $USER \$IPADDR -t -t '$SUDO $ACTION' 1>>$COPY_D/$LOG/\$SERVER.log 2>>$COPY_D/$LOG/\$SERVER.err &" >> $HOME/$OUTPUT_D/$SCRIPT
    sed -i "10s,&&,\&\& $SUDO,g" $HOME/$OUTPUT_D/$SCRIPT
    sed -i "10s,;,; $SUDO,g" $HOME/$OUTPUT_D/$SCRIPT
  fi
  echo -e "done\n" >> $HOME/$OUTPUT_D/$SCRIPT
  echo -e "rm -f $COPY_D/$CSV $COPY_D/*.sh" >> $HOME/$OUTPUT_D/$SCRIPT
}

# Execute
#########
execute()
{
  dos2unix $CSV 2>>/dev/null
  for PEONS in $( cat $HOME/$PEONLIST ); do
    SERVER=$( echo $PEONS | awk -F ',' '{ print $2 }' )
    IPADDR=$( echo $PEONS | awk -F ',' '{ print $1 }' )
    echo $SERVER $IPADDR > $HOME/$LOG/$SERVER.log
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $IPADDR "mkdir -p $COPY_D/$LOG" 1>>$HOME/$LOG/$SERVER.log 2>>$HOME/$LOG/$SERVER.err
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -rp $HOME/$OUTPUT_D/* $CSV $IPADDR:$COPY_D 1>>$HOME/$LOG/$SERVER.log 2>>$HOME/$LOG/$SERVER.err
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $IPADDR "/bin/bash $COPY_D/$SCRIPT" 1>>$HOME/$LOG/$SERVER.log 2>>$HOME/$LOG/$SERVER.err &
  done
}

# Review
########
review()
{
  header
  echo -e "You have provided the following:\n"
  echo "Server List: $CSV"
  if [ $USER = null ]; then
    echo "Connection type: SSH Key"
  else
    echo "Connection type: Username / Password"
    echo "Username: $USER"
  fi
  echo -e "Command to execute: $SELECTION\n\n"
}

# Verify
########
verify()
{
  unset VERIFY
  while [[ $VERIFY != @([yY][eE][sS]|[yY]|[nN][oO]|[nN]) ]]; do
    read -e -p "${BOLD}Is all the above correct?${NORMAL} [y/n/abort]: " VERIFY
    if [[ $VERIFY =~ ^([aA][bB][oO][rR][tT]|[aA])$ ]]; then
      clear
      exit 1
    fi
  done
}

# Any key
#########
any_key()
{
  read -n 1 -p "${BOLD}Press any key to continue...${NORMAL}"
}

# Main logic
############
main()
{
  while [[ $VERIFY != @([yY][eE][sS]|[yY]) ]]; do
    header
    echo -e "Target List Format : DATACENTER,IPADDRESS,HOSTNAME\n"
    csv
    connection_type
    list
    review
    verify
  done
  unset VERIFY
  peon_script
  execute
  echo -e "\nReview '/tmp/mage/logs' on the Peons\n"
}
################################################################################

################################################################################
# CONFIGURATION FUNCTIONS #
###########################

# Config header
###############
config_header()
{
  header
  TITLE="Welcome to Mage Configuration"
  printf "%*s\n" $(( ( $(echo $TITLE | wc -c ) + 80 ) / 2 )) "${BOLD}$TITLE${NORMAL}"
  echo -e "\n"
}

# Config Add Peon
#################
config_addpeon()
{
  while [[ $ANOTHER != [rR] ]]; do
    while [[ $VERIFY != @([yY][eE][sS]|[yY]) ]]; do
      config_header
      echo -e "${BOLD}Add Peon${NORMAL}\n"
      read -e -p "Enter Hostname: " HOSTNAME
      config_ipaddress
      read -e -p "SSH Key Type [dsa/rsa] (default is dsa): " ALGORITHM
      ALGORITHM=${ALGORITHM:-dsa}
      echo -e "\n${BOLD}Root Credentials are required for configuration.${NORMAL}\n"
      password
      echo -e "You have provided the following:\n"
      echo -e "${BOLD}$HOSTNAME $IPADDRESS${NORMAL}\n"
      echo -e "SSH Key type selected: $ALGORITHM\n\n"
      verify
    done
    unset VERIFY
    echo -e "\nConfiguring...\n"
    echo "$IPADDRESS,$HOSTNAME" >> $HOME/$PEONLIST
    SSHKEY=mage
    config_createkey
    config_copykey
    SSHKEY=peon
    config_peondepend
    config_createkey
    config_another
  done
  unset ANOTHER
}

# Config IP Address
###################
config_ipaddress()
{
  unset IPADDRESS
  while [[ ! $IPADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
    read -e -p "Enter IP Address: " IPADDRESS
  done
}

# Config Create SSH key
#######################
config_createkey()
{
  if [ $SSHKEY = mage ]; then
    if [ -f "/root/.ssh/${SSHKEY}_$ALGORITHM" ]; then
      return
    else
      ssh-keygen -t $ALGORITHM -f /root/.ssh/${SSHKEY}_$ALGORITHM -C "${SSHKEY}_key" -q -N ''
      sed -i "/IdentityFile ~\/.ssh\/id_dsa/a IdentityFile ~\/.ssh\/${SSHKEY}_$ALGORITHM" /etc/ssh/ssh_config
    fi
  elif [ $SSHKEY = peon ]; then
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root $IPADDRESS "if [ -f "/root/.ssh/${SSHKEY}_$ALGORITHM" ]; then exit 0; else ssh-keygen -t $ALGORITHM -f /root/.ssh/${SSHKEY}_$ALGORITHM -C "${SSHKEY}_$ALGORITHM" -q -N '' ; sed -i '/IdentityFile ~\/\.ssh\/id_dsa/a IdentityFile ~\/.ssh\/${SSHKEY}_$ALGORITHM' /etc/ssh/ssh_config; fi"
  fi
}

# Config Copy SSH Key
#####################
config_copykey()
{
  if [ $SSHKEY = mage ]; then
    cat /root/.ssh/${SSHKEY}_$ALGORITHM.pub | /usr/bin/sshpass -p $PASSWORD ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root $IPADDRESS 'mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys'
  elif [ $SSHKEY = peon ]; then
    SCRIPT=copy_peonkey.sh
    while [[ $VERIFY != @([yY][eE][sS]|[yY]) ]]; do
      config_header
      echo -e "Configure Mage to connect to end target servers via SSH Keys\n"
      echo -e "Target List Format : DATACENTER,IPADDRESS,HOSTNAME,PASSWORD\n"
      csv
      echo -e "\n\nYou provided: $CSV\n\n"
      verify
    done
    unset VERIFY
cat > $HOME/$OUTPUT_D/$SCRIPT << EOF
#!/usr/bin/env bash

if [ -f /root/.ssh/${SSHKEY}_dsa.pub ]; then
  ALGORITHM=dsa
elif [ -f /root/.ssh/${SSHKEY}_rsa.pub ]; then
  ALGORITHM=rsa
else
  echo -e "\nUnable to locate peon public key\n"
fi

PEON=\$( hostname | cut -c1-3 | tr -s [a-z] [A-Z] )

for SERVERS in \$( grep ^\$PEON $COPY_D/$CSV ); do
  SERVER=\$( echo \$SERVERS | awk -F ',' '{ print \$3 }' )
  IPADDR=\$( echo \$SERVERS | awk -F ',' '{ print \$2 }' )
  PASSWORD=\$( echo \$SERVERS | awk -F ',' '{ print \$4 }' )
  cat /root/.ssh/${SSHKEY}_\$ALGORITHM.pub | /usr/bin/sshpass -p \$PASSWORD ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root \$IPADDR 'mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys' &
done

rm -f $COPY_D/$CSV $COPY_D/*.sh
EOF
    execute
  fi
}

# Config Peon Dependencies
##########################
config_peondepend()
{
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root $IPADDRESS "if [ -f /etc/redhat-release ]; then yum -y -q install openssh-clients sshpass ; elif [ -f /etc/debian_version ]; then apt-get update && apt-get -yqq install openssh-client sshpass; elif [ -f /etc/SuSE-release ]; then zypper -nq in sshpass; else echo 'Unable to update the system - Unable to  determine package manager.'; exit 1; fi"
}

# Config Delete Peon
####################
config_delpeon()
{
  while [[ $ANOTHER != [rR] ]]; do
    while [[ $VERIFY != @([yY][eE][sS]|[yY]) ]]; do
      config_header
      echo -e "${BOLD}Delete Peon${NORMAL}\n"
      cat $HOME/$PEONLIST
      echo
      config_ipaddress
      echo -e "\n"
      verify
    done
    unset VERIFY
    echo -e "\nRemoving...\n"
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root $IPADDRESS "sed -i "/mage_key/d" /root/.ssh/authorized_keys"
    sed -i "/$IPADDRESS/d" $HOME/$PEONLIST
    config_another
  done
  unset ANOTHER
}

# Config Another
################
config_another()
{
  unset ANOTHER
  while [[ $ANOTHER != @([aA]|[rR]) ]]; do
  read -e -p "${BOLD}'A' to do another, or 'R' to return: " ANOTHER
  done
}

# Configure
###########
configure()
{
  while [[ $CONFIG != exit ]]; do
    config_header
    PS3='Enter selection: '
    OPTIONS=("Show all Peons" "Add Peon" "Delete Peon" "SSH Keys" "Exit Configuration")
    select OPT in "${OPTIONS[@]}"; do
      case $OPT in
        "Show all Peons")
          if [ -f "$HOME/$PEONLIST" ]; then
            config_header
            cat $HOME/$PEONLIST
            echo
            any_key
          else
            config_header
            echo -e "No Peons have been configured.\n"
            any_key
          fi
          break
          ;;
        "Add Peon")
          config_addpeon
          break
          ;;
        "Delete Peon")
          config_delpeon
          break
          ;;
        "SSH Keys")
          SSHKEY=peon
          config_copykey
          break
          ;;
        "Exit Configuration")
          if [ ! -f "$HOME/$PEONLIST" ]; then
            config_header
            echo -e "No Peons have been configured.\n"
            any_key
          else
            CONFIG=exit
          fi
          break
          ;;
        *) echo Invalid Selection;;
      esac
    done
  done
  unset CONFIG
}
################################################################################

################################################################################
# PROGRAM LOGIC #
#################
check  # Runs the check function
accept  # Runs the copyright function
main  # Runs the main function
################################################################################
exit 0  # Exit cleanly
