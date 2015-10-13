# Setup Guide #
guide for istalling all the software from scratch


## Hardware ##

needed hardware:
  * Rosbee robot, contains:
    * Paralax Board
    * netbook with ubuntu 11.04 or greater
    * Kinect or Laser scanner
    * asus wireless access point
  * Desktop PC with ubuntu
  * Wireless router


## Network ##
please make a network that is similar to the image on the [Quick Guide](http://code.google.com/p/rosbee/wiki/QuickGuide) page.
If you can ping from the robot to your desktop and vise versa your ok.

## Setting up the netbook ##

### Software ###
  * install the latest version of ROS
> follow the instructions on ros.org
> http://www.ros.org/wiki/ROS/Installation.
> our software is tested on Diamondback, so if you encounter problems with running the software you may want to try to downgrade to Diamondback. also make sure you configured ros correct. if you type `ros` in a terminal and bash tab you should see a list with available roscommands. if not open bashrc
```
sudo nano ~/.bashrc
```
> scroll to the bottom and check if you find a line that loads the ros's setup.bash.
> in diamondback:
```
source /opt/ros/diamondback/setup.bash
```

  * checkout the latest version of the rosbee repository.
> contact the project admin if you dont have a SVN account. in terminal do a checkout.
```
svn checkout https://rosbee.googlecode.com/svn/trunk/ rosbee --username <username>
```

> the simplest way is to checkout in the ROS\_PACKAGE\_PATH (echo $ROS\_PACKAGE\_PATH, to see whats your path). if your stack is not located in this path, ros wont be able to find our rosbee package.an other option is to add an custom path to the ROS\_PACKAGE\_PATH (export ROS\_PACKAGE\_PATH=$ROS\_PACKAGE\_PATH:yourpath) add this line of code to your bash script if you dont want to execute this line every time you open a terminal.

  * the trunk
> in the svn repository you will find 3 important packges , rosbee\_control, rosbee\_tf and rosbee\_param. rosbee\_control contains sources for controlling the motors and for reading encoders, to be more precisely the rosbee\_control stack interfaces with the paralax board. more info at [Rosbee\_Control](http://code.google.com/p/rosbee/wiki/Rosbee_Control). the rosbee\_tf contains sources that will calculate tranforms,poses and odometry. the robot uses this data to to navigate. more info at [Rosbee\_Odometry](http://code.google.com/p/rosbee/wiki/Odometry). the rosbee\_param package is basically an list with parameters to configure the navigation stack in the correct way so it matches with properties of the robot.

  * compile the code
> compiling of the code is easy. open an Terminal and run command:
```
rosmake rosbee_control rosbee_tf --pre-clean --rosdep-install
```

  * static ip
> set the ip of the netbook to 192.168.1.146. we also need to set the ROS\_IP parameter, so that ros also knows our ip. The easiest way is to set this parameter everytime the terminal is opened.every time an terminal is opened bashrc will be executed. So we need to add a line to he bashrc script. run the following command:
```
sudo nano ~/.bashrc
```
> scroll all the way down and add the following line:
```
export ROS_IP=192.168.1.146
```

  * ssh
> tip: install openssh server on the netbook. this way you dont have to crouch for controlling the netbook.


### Hardware ###

there is nothing special about connecting the hardware to the netbook with usb. Only make sure that the paralax board is connected to the robot first. if you used other hardware or mounted components on a different position you may want to check if they match with the source code. if you open /rosbee\_tf/src/rosbeetf.cpp you should see a couple defines.

## Setting up the Desktop ##
follow the same steps as with the netbook. Also we need to add an extra line to our bashrc script. Because we need to know wich ROS-system is the master. One of the pc's needs to be the master because we only can run one roscore. We decided that the netbook will be the ROS\_MASTER. you could also make the other pc's master but then you need to change your ROS\_MASTER\_URI parameter in your bashscript. add the following extra line the your bashrc script:
```
export ROS_MASTER_URI=http://192.168.1.146:11311
```
And don't forget to set an static ip in ubuntu. also make sure you set the ROS\_IP parameter to that IP.

you can repeat this steps for each desktop you want to add to the ROS network.


follow the instructions on the [QuickGuide](http://code.google.com/p/rosbee/wiki/QuickGuide) to start the nodes.