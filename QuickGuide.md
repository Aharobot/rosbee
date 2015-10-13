# Quick Guide #

the purpose of this page is to get the rosbee robot up and running. more in depth information about setting up the rosbee can be found under the installation guide.

first check:
  1. if the battery of the platform and the netbook is charged.
  1. you connected the Laserscanner to the USB port of the netbook.
  1. you connected the parallax board to the netbook via USB.
  1. the wireless dongle is connected to the ethernet port of the netbook. and also is connected to USB port for power.

  * note: always connect the paralax board first before connecting other USB devices on the netbook. otherwise the parallax board gets another device name assigned by the OS and therefore is not able to connect to the board.

## Network configuration ##
![https://rosbee.googlecode.com/svn/wiki/Netwerk.jpg](https://rosbee.googlecode.com/svn/wiki/Netwerk.jpg)

make sure your network looks like this. 1 desktop pc also will do fine. The Only purpose it has for us now is to show extra debug information, it also runs chrony server. we recommend you use desktop pc 2 (MSI 3D all in one) because of the computing power that is needed.

## Running Mapping/Navigation ##
  1. power up the netbook / desktop pc(s)
  1. flip the switch on the robot to "on 1" to turn on the platform.
  1. Open a terminal on one of the the desktop pcs (Ctrl+Alt+T)
  1. Run:
```
ssh robot@192.168.1.146
```
  1. Run:
```
roslaunch rosbee_control rosbee.launch
```
  1. Open a new terminal (Ctrl+Shit+T)
  1. Run:
```
roslaunch rosbee_control mapping_launch.launch
```
> > you will see that other nodes will be loaded and rviz will pop up. it may take a few seconds before all the nodes are correctly loaded.
  1. 
  1. you can check if the connection between nodes are correct by using rxgraph
  1. In Rviz make sure fixed frame is set to /map and Target frame is set to /base\_link
  1. On the left side of rviz you can check and uncheck different messages.
  1. press alt+tab to go back to the terminal, if you keep this terminal selected you are able to steer the rosbee robot. you may want to downsize the terminal to drive to robot and look at rviz at the same time.
  1. use q and e to turn the robot. with w an s you are able to drive in forward and backward direction. use these keys in combination with shift.
  1. drive around for a while till you got a proper map.
  1. for navigation, when you have a decent map, click on the 2d nav goal button in the top left corner of rviz and then click and hold left mouse button on a position on the map. if the mouse button is released the robot will try to drive towards its goal and avoid obstacles.