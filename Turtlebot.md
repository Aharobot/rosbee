# 1 Introduction #

We have used the Turtlebot package on two things, the first is the simulation during the time we didn’t had a robot at our disposal to use for testing our code. This package used gazebo for simulation of the Turtlebot, and the Turtlebot simulation files. It worked well but that was because the output information was more detailed than we had from the RosBee that we used before. The second package that we use is the main information about the Turtlebot itself. This contains all the drivers for the USA version of the Turtlebot. Because we have an EU version we need a bit more than only the normal package.

With the use of both of these packages we could test and update our code to work properly while not having the RosBee available.



# 2 Installation #

The installation of the packages needed for the things we used consists out of 3 steps, installation of the laptop that is connected to the Turtlebot directly. The second is the installation on the desktop for the software to steer and visualize the output. And the final step it the installation of the simulation software, this one is last because it exist mostly of the packages used at step 2.

**§ 2.1	Installation turtlebot laptop**

_2.1.1	Roomba/serial_

First thing we need to install are the roomba and serial communication stacks.
The serial stack:

```
svn co http://isr-uc-ros-pkg.googlecode.com/svn/stacks/serial_communication/trunk serial

cd serial/cereal_port/ && make

```
<a href='Hidden comment: 
Maybe use https://code.google.com/p/isr-uc-ros-pkg/downloads/detail?name=isr-uc-ros-pkg.rosinstall&can=2&q= instead?
'></a>
This downloads and builds [libcereal](https://code.google.com/p/isr-uc-ros-pkg/) from SVN.



The roomba stack:

```
svn co http://isr-uc-ros-pkg.googlecode.com/svn/stacks/roomba_robot/trunk roomba
```

This creates the map roomba on the current location with the svn checkout of the link. When u open the roomba map you give the command “make” to get the main build files. Then you go into the map roomba\_500\_series and do the command “make” again. This gives u the binary to run the communication program for communicating from the laptop to the roomba

_2.1.2	Turtlebot + ssh_

now we set up the main installation for the communication between the laptop and the roomba we can move on to getting the turtlebot files. to get the installation files u use the following command:

• Update apt repos

```
sudo apt-get update
```

• Install SSH to allow remote connections and update your TurtleBot software

```
sudo apt-get install ssh ros-electric-turtlebot-robot
```

the after u have don’t this u have installed the turtlebot files and the program ssh what gives u access to wireless communication.


_2.1.3	Chrony_

Now we need to install the last bit on the laptop and that is the chrony so that the communication doesn’t get timeouts because the system times are off.

• Install Chrony

```
sudo apt-get install chrony
```

• manually sync NTP

```
sudo ntpdate ntp.ubuntu.com
```


**§ 2.2	Installation main pc**

_2.2.1	Checklist_

What u need to have on the main pc are the following things:

-	A ROS installation of electric

-	An ogre installation for visualization

-	And be able to set up a network connection between both pc’s (ssh)


_2.2.2	Chrony_

Now we also need to install chrony on the main pc to make sure both are running on the same time so there are no timeouts because of time difference.

•  Install Chrony

```
sudo apt-get install chrony
```

•  manually sync NTP

```
sudo ntpdate ntp.ubuntu.com
```


_2.2.3	Turtlebot + ssh_

The last step to get the pc ready for communication between the pc and the laptop is installing ssh and the turtlebot files. It are the same commands as used before.

• Update apt repos

```
sudo apt-get update
```

• Install SSH to allow remote connections and update your TurtleBot software

```
sudo apt-get install ssh ros-electric-turtlebot-robot
```


**§ 2.3	Gazebo + Simulation turtlebot**

_2.3.1	Installation (requires root access)_

For more details on the installation check the following link: http://playerstage.sourceforge.net/doc/Gazebo-manual-svn-html/install.html

The things we did to install the package are as followed:
```
$ tar xvzf gazebo-(version).tar.gz

$ cd gazebo-(version)

$ scons
```

Note that scons will fail if any of the required packages are missing. Once Gazebo has been built, it can be installed:

```
$ su
$ scons install
$ exit
```
Gazebo is now ready to run; try:
```
	$ gazebo /usr/local/share/gazebo/worlds/pioneer.world
```

_2.3.2	Turtlebot simulation program_

With the 2 following command we can get all the packages we need to install the Turtlebot simulation that can run in gazebo.

```
sudo apt-get update 

sudo apt-get install ros-electric-turtlebot-simulator-desktop
```

this will take a few minutes but after its done it is fully installed and ready for usage.

# 3 the simulation #

**§ 3.1	Simple simulation and driving**

To start the simulation without anything else we use the following command:

> roslaunch turtlebot\_gazebo turtlebot\_empty\_world.launch

After this is done we can now make the robot in the simulator drive around. This can be done in 2 ways, one it with a single command each time and a second is with the teleop application.
To command the TurtleBot to drive in a circle with a normal command we use:
```
  rostopic pub -r 5 cmd_vel geometry_msgs/Twist '[0.1, 0, 0]' '[0, 0, 0.2]'
```
The above command publishes the twist command at a rate of 5Hz because the TurtleBot will timeout a velocity command if it does not receive a new command within 0.6 seconds of the last command.
The second way is by using the teleop command:
```
	roslaunch turtlebot_teleop keyboard_teleop.launch 
```
This will launch a program that lets the robot drive on keyboard input.

**§ 3.2	Mapping during simulation**

This is a bit more advanced than 3.1, now we are going to make our own package and write a bit of code too.

To create a new package and cd into it after it we use the following commands:
```
cd ~
mkdir sim_workspace
rosws init ~/sim_workspace /opt/ros/electric
cd ~/sim_workspace
mkdir unversioned
rosws set unversioned --detached
. ~/sim_workspace/setup.bash
cd unversioned
roscreate-pkg turtlebot_gazebo_tutorial turtlebot_gazebo
cd turtlebot_gazebo_tutorial
```
First we go into the root of the system and there we make a workspace for our package. We make it use the electric version as base. After this is done we make a map that that we detach so we can put all our software in it without changing the real packages.

Now this is done we can make our world, check this link for the code: http://ros.org/wiki/turtlebot_simulator/Tutorials/Building%20a%20Map%20in%20TurtleBot%20Simulator

Follow al steps at 2 making our own package.

To run the program that is just made we use:
```
	roslaunch turtlebot_gazebo_tutorial build_map.launch
```
this will bring up the gazebo with the world and the Turtlebot. Now we can drive around like we did before but there are now objects around us. While driving the simulation makes a map. We can look at this map by using this command:
```
    rosrun rviz rviz -d `rospack find turtlebot_navigation`/nav_rviz.vcg
```
# 4 software #

**§ 4.1	Basis**

To get the communication going we need to get connection from the pc to the laptop. For this we use the ssh we installed earlier. The command should be something like this:
Ssh username@ipadress  	 for example	 ssh robot@192.168.1.148

After this is done you may have to give a password for the connection. Now we have the ssh running we need to open a roscore and the roomba communication node. For this we need 2 terminals logged into the robot (use the above command once in each terminal)

In the first terminal we give the command:
```
 Roscore
```
In the second terminal we give the command to start the roomba node:
```
rosrun roomba_500_series roomba560_node
```

now we have the communication established between the laptop and the roomba we can start sending commands to the roomba.

**§ 4.2	Steering**

This will look similar to the steering used in 3.1 of this document. This is because the base steering has all the same kind of protocol setup for it.

_4.2.1	Commands_

Open a new terminal on the PC and leave the 2 connected to the laptop open.
Now in the new terminal we can use commands to steer the robot. Once the command is send the robot will do that move till the next command is send.
```
     rostopic pub cmd_vel geometry_msgs/Twist '[0.1, 0, 0]' '[0, 0, 0.2]'
```
this command is used for moving the robot. Now I will explain the parameters.
Rostopic: this is the command with this command we are able to send or read stuff from the topics that are running at this moment.
Pub : this is the parameter for publishing a command
Cmd\_vel: this is the parameter for the topic we send the command to.
Geometry\_msgs/Twist: this is the parameter for the message type.
'[0.1, 0, 0]' : this is the parameter for the forward speed, more wil be explained in the data part of the document.
'[0, 0, 0.2]' : this is the parameter for the turning speed, more will be explained in the data part of the document


_4.2.2	Keyboard_

Now we know what the commands look like we can make it easier with sending the input with the keyboard. For this we need to start the keyboard\_teleop node. This can be done by the following command:
```
Roslaunch turtlebot_teleop keyboard_teleop.launch
```
This will start a program what we can use for steering the robot. We can decide the direction and the speed in here. More will be explained later on in this document.



**§ 4.3	Mapping and navigation**

For the mapping there is 1 way to do this, for navigation there are 2. I will explain the mapping/navigation combination first and after that the 2nd navigation possibility.

_4.3.1	Mapping and saving_


After starting the roomba driver and the Turtlebot bring up we can start the mapping package with:
```
	roslaunch turtlebot_navigation gmapping_demo.launch
```
> this command starts the kinect and gmapping with both running the information that comes from the kinect is put into making a map. Now to make the map visible we need to start Rviz. This can be done with the following command:
```
rosrun rviz rviz -d `rospack find turtlebot_navigation`/nav_rviz.vcg
```
with this command rviz is already setup to get all the right information from the gmapping package. Now we can drive around with the keyboard using the teleop from 4.2.2.

after a driving around a little while we get a map, now we want to save this map for later use. We do this with the following command:
```
rosrun map_server map_saver -f /tmp/my_map
```
after it said “done” in the terminal we can use crtl + c to shut down the program.

_4.3.2	Navigation_

Now we still have Rviz open we can use the 2D Nav Goal button to select a place where the robot needs to go to. Now the robot will start to drive towards that point, it will fail if the path is blocked but otherwise he will reach its goal and stay there fr the next command. This is the first method we can use. But this can only be used right after mapping the area, and that is not always the way we want it. So the 2nd method start from the map we saved a little while ago.

First steps we take is starting the driver and the bring up again. Now this is done we start the package we need for navigation on a saved map. We use this command:
```
roslaunch turtlebot_navigation amcl_demo.launch map_file:=/tmp/my_map.yaml
```
it will start the program we need with the file we just saved. Now we need to launch rviz. The program will see the map loaded in the Turtlebot. The command we use is the same as during the making of the map:
```
rosrun rviz rviz -d `rospack find turtlebot_navigation`/nav_rviz.vcg
```
we need to set the robot to its place on the map, we have 2 steps for it. Click the "2D Pose Estimate" button. After that Click on the map where the Turtlebot is and drag in the direction the Turtlebot is pointing. This way we will see a arrow from the point the Turtlebot stands to the direction he is looking. Now we have the same setup as before and can navigate the robot the same way.

# 5 Links #

http://ros.org/wiki/Robots/TurtleBot
main turtlebot page, here u can find more about the installing and tutorials u have with the robot.

http://www.ros.org/wiki/roomba_robot
the page for the roomba package

http://www.ros.org/wiki/serial_communication
the page for the serial communication

http://www.ros.org/wiki/simulator_gazebo
the page for the simulator

http://ros.org/wiki/turtlebot_simulator
the page of the Turtlebot of the simulator