#! /usr/bin/bash
########## Terminal Notice #######
echo "source /common/scripts/super_echo" >>~/.bashrc
### ROS domain
echo "recho ROS_DOMAIN_ID : $ROS_DOMAIN_ID" >>~/.bashrc

# PATH
echo "export PATH=/common/scripts:${PATH}" >>/root/.bashrc

# Setup to colorize bash
sed -i -e "s/#force_color_prompt=yes/force_color_prompt=yes/" /root/.bashrc
# prompt color change in container
echo "PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\[\033[00m\]\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;34m\]\w\$\[\033[00m\] '" >>~/.bashrc

# assets commands
echo "alias home='source home.sh'" >>~/.bashrc
echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >>~/.bashrc
echo "source ~/ros2_ws/install/local_setup.bash" >>~/.bashrc
echo "source ~/ros2_ws/install/setup.bash" >>~/.bashrc
