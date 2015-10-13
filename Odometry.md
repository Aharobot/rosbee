# Odometry #
## rosbeetf.cpp ##
_by Sven Rademakers_      3-Oct-2011



**Note**: This document assumes familiarity with ROS and how to use it. Also knowledge about rviz and tf's.

![https://rosbee.googlecode.com/svn/wiki/rviz_screen.png](https://rosbee.googlecode.com/svn/wiki/rviz_screen.png)

Odometry is the use of data from moving sensors to estimate change in position over time. Odometry is used by some robots to estimate (not determine) their position relative to a starting location. This method is sensitive to errors due to the integration of velocity measurements over time to give position estimates.
**_wikipedia.org_**

## rosbee\_tf node ##

ROS uses Odometry to estimate the position of the robot. Especially the Navigation stack uses odometry. Because every robot is different (2 wheeled, 4 wheeled, size of wheels ,distance bewteen wheels) we need to implement odometry manual. In our case it means that we need to know the the radius of the wheels, the length of the wheelbase and some information about wheel rotations, encoder values. Fortunate ROS gives us a little hand with the transformation of tf-frames.

in this document i will describe the steps that I took to get the Odomerty where it stands now.

all code about Odometry is implemented in the rosbee\_tf package.
path: /trunk/rosbee\_tf
sources: /trunk/rosbee\_tf/src/

more info is found at
http://www.ros.org/wiki/navigation


First we made sure that we can read encoder values from the paralax-board that is connected the the encoders.this specific code is implemented in the rosbee\_control stack.
after the encoder values are obtained, we translate the incoming encoder-pulses to a distance. which we can calculate Odometry with.
the last step is to publish some messages over ROS. If you look at the specification of the navigation stack, the move\_base node to be precisely, you see that in order to get navigation working you need to publish 2 types of messages. a TF message and an Odomety message.

Node [/tfbroadcaster]
Publications:
  * /rosout [rosgraph\_msgs/Log]
  * /tf [tf/tfMessage]
  * /odom [nav\_msgs/Odometry]

Subscriptions:
  * /enc [rosbee\_control/encoders]
  * /tf [tf/tfMessage]

### Read Encoders ###
to get information about encoders you first need to get the rosbee\_control stack up and running. this stack publishes encoder values over ROS in the format descriped in rosbee\_control/msg/encoders.msg. Because of some computing limitations of the paralax we only can publish encoder values at a rate of  max 10hz. another problem is if we sample at 10 hz the delta of the encoder pulses will be 0. this due a low resolution of the encoders on the wheel. below i have posted some code from the rosbee\_tf source, i left the unimportant parts blank.

```
void enc(const rosbee_control::encoders::ConstPtr& msg)
{
	//set the prevEnc values only the first time, because there is no initial value when
	//entering this method for the first time. assuming the values will never be 0.
	if(prevEncL == 0 && prevEncR == 0)
	{
		prevEncR = msg->rightEncoder;
		prevEncL =  msg->leftEncoder;
    return;
	}

	ROS_DEBUG_NAMED("Odometry","prevEnc r:%f ,PrevEnc l:%f NewEnc l:%i, NewEnc R:%i",prevEncR,prevEncL, msg->leftEncoder,msg->rightEncoder);
	//get the difference between last and current position
	double delr = msg->rightEncoder - prevEncR;
	double dell = msg->leftEncoder -  prevEncL;
	ROS_DEBUG_NAMED("Odometry","delta r:%f pulses,delta l:%f pulses",delr,dell);

	//calculate the distance the wheels have traveled, compared to last measurement.
	double right = (OMTREKWHEEL*delr)/FULLCIRCLEPULSE;
	double left = (OMTREKWHEEL*dell)/FULLCIRCLEPULSE;
	ROS_DEBUG_NAMED("Odometry","New distance: left wheel:%lfm right wheel:%lfm",left,right);
        
        //calculate odometry/tf tree

	//save the encoder values for next call
	prevEncR = msg->rightEncoder;
	prevEncL = msg->leftEncoder;

 ROS_DEBUG_NAMED("Odometry"," ");
}


int main(int argc, char **argv) {

	//ros initialisation
	ros::init(argc, argv, "tfBroadcaster");
	ros::NodeHandle n;

	//subscribe to encoders. every time an encoder value is published over ROS the enc method is called.
	//we need this values to calculate the position/speed of the platform.
	ros::Subscriber subx = n.subscribe("/enc",10,enc);
        
        // init some other stuff

	//run node.
	ros::spin();

	return 0;
}

```

### Calculate trajectories ###
when driving with the robot we have roughly 3 scenario's: driving in a straight line, pivoting around axis, and making a corner.

this is a picture that i found on the internet that describes almost the same  logic that i used in the rosbee\_tf stack:

![https://rosbee.googlecode.com/svn/wiki/dsODO_FC_DeadReckoning.gif](https://rosbee.googlecode.com/svn/wiki/dsODO_FC_DeadReckoning.gif)

At this point the robot cant make a corner, due to hardware limitations, so we haven't implemented this state yet.

  * driving in a straight line
> > this is the simplest calculation, we just look at the distance that is travelled by one wheel. code-wise i have implemented it like this:

```

if (fabs(r-l) <= MARGIN) {
		posy = ((l+r)/2) * SinPrev;
		posx =((l+r)/2) * CosPrev;	
		ROS_DEBUG_NAMED("Odometry","===Straight Line===");	
	}

```

  * pivoting
```
double dtheta = (r-l)/WHEELBASE;
		theta =  fmodf((theta+dtheta),(2*M_PI));
		CosPrev=cosf(theta); // for the next cycle
    SinPrev=sinf(theta);
		ROS_DEBUG_NAMED("Odometry","===Pivoting===");	
```

  * making a corner

> not implemented yet

### Setting up an TF-Tree ###

first we needed a transform model of the robot,TF tree. a TF tree give us information about relative positions and rotations. as you probably know a tf tree is chain with transforms that have one parent but can have multiple child's.
in the picture above(rviz window) you see an example of the tf tree of the rosbee robot.
as you can see in the left panel an tree has only one topframe, in this case /map. the /map frame has 1 child /odom which has also an child /base\_link. /base\_link frame is an important frame. Most nodes use that frame. This frame mostly represents the center base point of the robot. We also have 2 wheel frames, a laser frame  and a kinect frame.

code wise it looks like this:
```
void publishTf(const double encL, const double encR, const geometry_msgs::PoseStamped base_pose)
{
	static tf::TransformBroadcaster br;
	tf::Transform transform;

	transform.setOrigin(tf::Vector3(base_pose.pose.position.x,base_pose.pose.position.y,base_pose.pose.position.z));
	transform.setRotation(tf::Quaternion(base_pose.pose.orientation.x ,base_pose.pose.orientation.y,base_pose.pose.orientation.z,base_pose.pose.orientation.w));
	br.sendTransform(tf::StampedTransform(transform, ros::Time::now(),"odom", "base_link"));

	transform.setOrigin( tf::Vector3(DISTANCEBASETOSCANNER));
	transform.setRotation(tf::createQuaternionFromRPY(0,0,0));
	br.sendTransform(tf::StampedTransform(transform, ros::Time::now(),"base_link", "openni_camera"));

	transform.setOrigin( tf::Vector3(DISTANCEBASETOLASER));
	transform.setRotation(tf::createQuaternionFromRPY(0,0,0));
	br.sendTransform(tf::StampedTransform(transform, ros::Time::now(),"base_link", "laser"));

	transform.setOrigin( tf::Vector3(DISTANCEBASETOLWHEEL));
	transform.setRotation(tf::createQuaternionFromRPY(0,encL,0));
	br.sendTransform(tf::StampedTransform(transform, ros::Time::now(),"base_link", "leftWheel"));

	transform.setOrigin( tf::Vector3(DISTANCEBASETORWHEEL));
	transform.setRotation(tf::createQuaternionFromRPY(0,encR,0));
	br.sendTransform(tf::StampedTransform(transform, ros::Time::now(),"base_link", "rightWheel"));

	ROS_DEBUG_NAMED("TF","TF Sended");
}

```
with the TransformBroadcaster we are able to send tf's over ros. these transforms will be automatically posted on the /tf topic. In the code above we send 5 different transforms to the /tf topic. this function will be executed every time an new encoder message is published over the network.