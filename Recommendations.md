# Recommendations #

at this moment the process is slowed down by the process power of the computers and the netbook. its recommended to update these to more powerful ones. recommended it to use at least an i5 processor with 4gb ram memory.

test processor usage on netbook
|task|Processor usage| recommended|
|:---|:--------------|:-----------|
|Roscore a simple program that manages the information flow|5-10%          |less than 5% |
|gathering kinect immages|20-30%         | less than 10% |
|sending the kinect images|70-80%         |30%         |
|sending pointcloud data|150%           |50%         |

we see here that there is a lot of the processor used when we start up the kinect, moostly by sending it over the network

Test processor usage on workstation 1

|task|Processor usage|recommended|
|:---|:--------------|:----------|
|gathering kinect data|10%            |less than 10% |
|sending kinect data|30%            |20%        |
|sending pointcloud (3d information) data|50%            |40%        |
|RGBD slam with kinect single frame |	150%          |70%        |
|RGBS slam with kinect stream	|220%           |95%        |

as seen here we need a lot more processor power when we are visualizing the data from the kinect.

Test stream data over network

|task|time delay|recommanded|
|:---|:---------|:----------|
|one command| less than 0.1 seconds|	Minder dan 0.1 seconds|
|a immage stream from the kinect|2 seconds |	less than 1 second|
|a 3d stream from the kinect |5 seconds |1 second   |

as seen here for a simple command we have enough, but when we want to send more or bigger information the connection slows down a lot.