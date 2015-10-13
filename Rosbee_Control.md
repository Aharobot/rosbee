# Rosbee\_control #


# Introduction #
on this page we will try to explain the setup of the rosbee\_control package and the move\_platform node.
the rosbee\_control package contains the main launch files for the rosbee project. this includes the launch file for the robot and launch files for mapping and navigating on an existing map. it also contains the move\_platform node, which provides an interface to the platform, allowing it to be controlled with cmd\_vel messages and publishing encoder values for the odometry node.

# Launch files #
the rosbee\_control package contains the following launch files:
  * rosbee.launch
  * pc\_launch.launch
  * mapping\_launch.launch

### rosbee.launch ###
rosbee.launch is the launch file to bring up the robot. the launch file starts the following nodes: odometry, move\_platform and the kinect or laser.
the line for the laser is:
```
<node name="hokuyo_node" pkg="hokuyo_node" type="hokuyo_node" />
```
the line for the kinect is:
```
<include file="$(find pointcloud_to_laserscan)/launch/kinext_laser_2.launch" />
```

to select the kinect or laser you will need to uncomment there line in the launch file.

### pc\_launch.launch ###
pc\_launch.launch runs everything from the navigation stack. but only works if you have a map of the area. (as it doesnt start the gmapping node).
this launch file want to get the location of the map of the area you are going to drive in. to specify the location for the map you will need to start the launch file in the following way:
```
roslaunch rosbee_control pc_launch.launch map:=<location of your map>
```
when no map(yaml) file is specified it will start the navigation stack with a map of the mechatronica lab(not recommended)

### mapping\_launch.launch ###
mapping\_launch.launch is the launch file that we normally use for testing. it will start everything that is needed to make a map(except the robot it self) and a teleop keyboard, which allows you to send commands to the robot with the qwe and s keys.

when you run this launch file you will notice rviz starting. when you see the costmap being shown in rviz everything is done starting.

# move\_platform #

the move\_platform node allows us to control the platform with ros messages. it listens on the topic "/cmd\_vel" (the default ros topic for move commands) and publishes encoder values on the "/enc" topic.

## communicating with the platform ##
to communicate with the platform we use a serial connection. we have used 2 communication protocols, the one the original platform used and a simplified version. right now we use the simplified version of the protocol.

### original protocol ###
all the commands in the original protocol are plain text and use the following common syntax:
```
$(command number),(command parameters)<CR>#<EOT>
```
where (command number) is the number representing the command, and (command parameters) are the parameters for that specific command. parameters are separated by comas.
`<CR>` represents a carriage return (ascii 13)
`<EOT>` represents an end of transmission (ascii 4)

#### 900 move command ####
sets the platform to move at the given speeds.
```
$900,cntr,speed,dir<CR>#<EOT>
```
cntr, is a counter which will increase with 1 every move command <br>
speed, is the forward speed for the platform in the range [-128..127] <br>
dir, is the directional speed for the platform in the range [-128..127]<br>
<h4>901 enable motion</h4>
enables motion by the platform.<br>
<pre><code>$901,Enable&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
Enable, value: 1 means motion will be enabled, 0 means motion will be disabled. any other values are invalid.<br>
<h4>902 enable pc control</h4>
enables pc control on the platform.<br>
<pre><code>$902,Enable&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
Enable, value: 1 means pc control will be enabled, 0 means pc control will be disabled. any other values are invalid.<br>
<h4>908 clear errors</h4>
clears all current set errors on the platform.<br>
<pre><code>$908&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
<h4>909 enable US sensors</h4>
enables the US sensors on the platform<br>
<pre><code>$909,Enable&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
Enable, value: 1 means the US sensors will be enabled, 0 means that the US sensors will be disabled. any other values are invalid.<br>
<h4>911 query wheel position</h4>
requests the current encoder values<br>
<pre><code>$911&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
reply:<br>
<pre><code>$911,wheel1,wheel2,&lt;CR&gt;#&lt;EOT&gt; <br>
</code></pre>
wheel1, is the encoder value of wheel1, as an unsigned 16 bit int (uint16).<br>
<br>
<BR><br>
<br>
<br>
wheel2, is the encoder value of wheel2, as an unsigned 16 bit int (uint16).<br>
<h4>912 query us sensors</h4>
requests the last measured distance from the US sensors<br>
<pre><code>$912&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
reply:<br>
<pre><code>$912,sensor0,sensor1,sensor2,sensor3,sensor4,sensor5,sensor6,sensor7,sensor8,sensor9,&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
sensor#, is the encoder value of sensor#, as an 32 bit int (int32).<br>
<h4>913 query status</h4>
requests the current status of the platform<br>
<pre><code>$913&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
reply:<br>
<pre><code>$912,MoveMode,LastAlarm,XbeeTime,getCntr,Enabled,PcEnable,PfStatus,MainCntr,SafetyCntr,Version&lt;CR&gt;#&lt;EOT&gt;<br>
</code></pre>
<code>MoveMode</code>, values: 0 means manual mode, 1 means US sensor control.<br>
<br>
<BR><br>
<br>
<br>
<code>LastAlarm</code>, contains the last error.<br>
<br>
<BR><br>
<br>
<br>
<code>XbeeTime</code>, <code>XbeeTime</code>/80000 is the time of the Xbeecomm in ms<br>
<br>
<BR><br>
<br>
<br>
<code>getCntr</code>, HB52 counter<br>
<br>
<BR><br>
<br>
<br>
Enabled, values: 0 motion is disabled, 1 motion is enabled<br>
<br>
<BR><br>
<br>
<br>
<code>PcEnable</code>, values: 0 pc control is disabled, 1 pc control is enabled<br>
<br>
<BR><br>
<br>
<br>
<code>PfStatus</code>, status bits values:<br>
<blockquote>0. Serialbit, 0= Serial Debug of 1= Serial pdebug port on <br>
<br>
<BR><br>
<br>
<br>
<code>1.</code> USAlarm, US alarm bit: 1= object detected in range <br>
<br>
<BR><br>
<br>
<br>
2. <code>PingBit</code>, 0= Ping off 1= Ping on <br>
<br>
<BR><br>
<br>
<br>
3. <code>EnableBit</code>, 0= Motion <code>DisablePfd</code> 1= Motion enabled <br>
<br>
<BR><br>
<br>
<br>
4. PCEnableBit, PC Enable -> Pf Enable <br>
<br>
<BR><br>
<br>
<br>
5. PCControlBit, PC In control <br>
<br>
<BR><br>
<br>
<br>
6. <code>CommCntrBit</code>, Xbee Timout error <br>
<br>
<BR><br>
<br>
<br>
7. <code>MotionBit</code>, Platform moving <br>
<br>
<BR><br>
<br>
<br>
8. <code>NoAlarmBit</code>, No alarm present <br>
<br>
<BR><br>
<br>
<br>
<code>MainCntr</code>, mainloop counter <br>
<br>
<BR><br>
<br>
<br>
<code>SafetyCntr</code>, safety counter<br>
<br>
<BR><br>
<br>
<br>
Version, platform version number<br>
<br>
<BR><br>
<br>
<br>
<br>
<BR><br>
<br>
</blockquote>


<h3>simplified protocol</h3>
in the simplified protocol we only send the PWM values the platform has to use. after every set of PWM values the platform responds with its current encoder values.<br>
for sending the PWM values we use the following protocol.<br>
<pre><code>$(leftpwm);(rightpwm)#<br>
</code></pre>
where (leftpwm) is the pwm value for the left wheel and (rightpwm) is the pwm value for the right wheel<br>
<br>
the platform answers the with the encoder values according to the following protocol.<br>
<pre><code>$(leftencoder);(rightencoder)#<br>
</code></pre>
again (leftencoder) is the encoder value of the left wheel, (rightencoder) is the value of the right wheel.<br>
<br>
<h2>move_platform.cpp</h2>
move_platform.cpp is the main file of the move_platform nodes. it sets up the services and the subscriber to cmd_vel.<br>
the while loop in move_platform.cpp also makes sure that the platform is updated at at least 5 hertz. it does so by checking if it has been more than 200ms since the last receive, if so it sends a 0 value to the platform making it stop.<br>
<br>
<h2>the platform class</h2>
the platform class implements the communication with the platform.<br>
because we had a couple of revisions in the platform we have a couple of different version of the platform class, they all use the same functions but the implementation is different and some functions might not be supported.<br>
the following versions of the Platform class exist:<br>
<ul><li>xbee Platform: can be found in the xbeeplatform tag<br>
</li><li>wired Platform: last update was on <a href='https://code.google.com/p/rosbee/source/detail?r=99'>r99</a>.<br>
</li><li>revised wired Platform: on the laptop to be added</li></ul>

<h3>xbee Platform</h3>
the xbee platform was the first version of the platform. it communicated with the laptop over xbee. the xbee was cause for a lot of instability thats why this version included a restriction on command speed (5 hz max (platform could handle 8 but we wanted to be on the save side)) it also had a thread dedicated to reading the messages from the platform to prevent messages being lost (if a message wasnt read right away it was lost as the xbee connection didnt seem to be buffered).<br>
<br>
<h3>wired Platform</h3>
after a while we replaced the xbee connection(between the robot and the laptop) with an serial connection. this gave us a more stable connection. unfortunately the speed of the platform didnt improve. at this version of the platform we were still communicating at 5-8 hertz<br>
<br>
<h3>revised wired platform</h3>
this is the final verion of the platform. for this version we have rewritten the software of the platform it self, and introduced a greatly reduced version of the communication protocol. this version of the platform responds at an high speed and makes it possible to work at over 50 hertz.<br>
this version of the platform also contains the least functionalities, it only allows you to set the speed with which the platform should move.<br>
to make sure the published encoder values stay up to date the node will, when it hasnt send a command to the platform for 200ms, resend the previous command. the node also have a build in timeout in waiting for a reply, to make sure package loss wont crash the node, locking it in its read cycles.