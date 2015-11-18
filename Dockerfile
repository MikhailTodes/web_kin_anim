#Must use google's python compatible debian image as base
FROM gcr.io/google_appengine/python-compat

#Install linux packages
RUN apt-get update && apt-get install -y \
	python-setuptools \
	wget \
	git \
	python-numpy python-scipy \
	gcc \
	make \
	cmake \
	build-essential \
	checkinstall
RUN easy_install pip

#Install app requirements
ADD requirements.txt /app/
RUN pip install -r /app/requirements.txt
ADD . /app/

#Set-up ROS repos
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu wheezy main" \
	> /etc/apt/sources.list.d/ros-latest.list'
RUN wget https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
	-O - | apt-key add -

#Enable Wheezy Backports repo
RUN sh -c 'echo "deb http://http.debian.net/debian wheezy-backports main" \
	> /etc/apt/sources.list.d/backports.list'
RUN apt-get update && apt-get upgrade -y

#Install rosdep and rosinstall to bootstrap ROS
RUN pip install rosdep rosinstall_generator wstool

#Initialize rosdep
RUN rosdep init && rosdep update

#Create workspace dir
RUN mkdir -p /home/vmagent/ros_ws

#Create catkin_ws
RUN cd /home/vmagent/ros_ws && \
	rosinstall_generator ros_comm geometry_msgs joint_state_publisher \
	robot_state_publisher xacro --rosdistro indigo --deps --wet-only \
	--exclude roslisp --tar > indigo-custom_ros.rosinstall
RUN cd /home/vmagent/ros_ws && \
	wstool init -j4 src indigo-custom_ros.rosinstall

#Create external source dir
RUN mkdir -p /home/vmagent/ros_ws/external_src

#Install libconsole-bridge-dev
RUN apt-get install -y libboost-system-dev libboost-thread-dev
RUN git clone https://github.com/ros/console_bridge.git \
	/home/vmagent/ros_ws/external_src/console_bridge
RUN cd /home/vmagent/ros_ws/external_src/console_bridge && \
	cmake /home/vmagent/ros_ws/external_src/console_bridge/. && \
	checkinstall --nodoc -y --pkgname=libconsole-bridge-dev make install

#Install liburdfdom-headers-dev
RUN git clone https://github.com/ros/urdfdom_headers.git \
	/home/vmagent/ros_ws/external_src/urdfdom_headers
RUN cd /home/vmagent/ros_ws/external_src/urdfdom_headers && \
	cmake /home/vmagent/ros_ws/external_src/urdfdom_headers/. && \
 	checkinstall --nodoc -y --pkgname=liburdfdom-headers-dev make install

#Install liburdfdom-dev
RUN apt-get install -y libboost-test-dev libtinyxml-dev
RUN git clone https://github.com/ros/urdfdom.git \
	/home/vmagent/ros_ws/external_src/urdfdom
RUN cd /home/vmagent/ros_ws/external_src/urdfdom && \
	cmake /home/vmagent/ros_ws/external_src/urdfdom/. &&\
	checkinstall --nodoc -y --pkgname=liburdfdom-dev make install

#Install liblz4-dev
RUN apt-get -y -t wheezy-backports install liblz4-dev

#Clone kinematics_animation, universal_robot and barrett_model packages
RUN git clone https://github.com/sherifm/kinematics_animation.git \
	/home/vmagent/ros_ws/src/kinematics_animation
RUN git clone https://github.com/sherifm/universal_robot.git \
	/home/vmagent/ros_ws/src/universal_robot
RUN git clone https://github.com/sherifm/barrett_model.git \
	/home/vmagent/ros_ws/src/barrett_model

#Resolve some dependencies with rosdep
RUN cd /home/vmagent/ros_ws/ && \
	rosdep install --from-paths src --ignore-src --rosdistro=indigo -y -r \
	--os=debian:wheezy --as-root="apt:false" \
	--skip-keys="python-rosdep python-rospkg python-catkin-pkg"

#Build the catkin workspace
RUN cd /home/vmagent/ros_ws/ && \
	./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release \
	--install-space /opt/ros/indigo

#Set-up locale environment
ENV LC_ALL C