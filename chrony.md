# Introduction #

in  the project we use chrony to synchronize the time on the different  machines we run. (the robot: 192.168.1.146, desktop 1: 192.168.1.185 and  desktop 2: 192.168.1.191) all the folowing guides will asume these ip's  are used. if you plan on using a different ip you will have to take  this into account when setting up chrony.
ROS is really strict when it comes to timing on TF's. to prevent ROS from  warning about it we setup desktop 1 as a chrony server and let the other computers synchronize their time with it.


# Setting up chrony on clients #

to  set up chrony on a system you first need to install chrony on it. to do  so you have to run the command: 'sudo apt-get install chrony'.

now chrony is installed we need to edit the chrony configuration file.
the configuration file can be found in '/etc/chrony'.

open the file "chrony.conf",make sure you do this with super user permissions otherwise you wont be able to save it.

at  the top of the config file you will see a number of servers which  chrony tries to connect to. delete all and add the line: "server  192.168.1.185". this will force chrony to synchronize with desktop 1  instead of the internet.
now that we have  added desktop 1 as the server we want to syncronize we will need to  allow desktop 1 to chance the time on our system. to do this you will  have to scroll down a bit. untill you see a couple of lines starting  with "allow". delete all these lines and replace them with the  following:"allow 192.168.1.185".

restart the chrony deamon with the command "sudo invoke-rc.d chrony restart"

chrony should now synchronise your system with the server.


# Setting up chrony as a server #

to  setup chrony as a server we ofcourse first need to install chrony.  start by running the command 'sudo apt-get install chrony'.

now that we have chrony we need to edit the configuration file.
the configuration file can be found in '/etc/chrony'.

open the file "chrony.conf", make sure you do this with super user permissions else you wont be able to save it when your done.

in  the config file scroll down untill you find a number of line starting  with: "allow". delete these lines and replace them with: "allow  192.168.1" this will allow any pc in the 192.168.1.x range to  synchronize with the server.

also add a  line: "manual" in the file. this will tell chrony it doesnt have to  synchronize with the internet and that the time might be manually  updated.

restart the chrony deamon with the command "sudo invoke-rc.d chrony restart"

you have now setup your system as a chrony server.