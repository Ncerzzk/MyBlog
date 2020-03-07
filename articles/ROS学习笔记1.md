# ROS学习笔记1 
ctime:2020-03-04 17:59:00 +0900|1583312340

标签（空格分隔）： 技术

---

一直以来都想学ROS，不过苦于没有机缘。现在实验室的项目要用到，不得不学了。

### catkin 
- 一种package(ROS包)的构建工具

### ROS文件系统
- Package  包括Package的可执行文件、库等
- Manifests 用来描述当前package的一些信息，版本等

### Package




- 权限问题解决方式：

```shell
sudo rosdep fix-permissions

rosdep update
```


### 一些ROS命令

- catkin_init_workspace
- catkin_create_pkg
- catkin_make
- roscd rosls  类似于cd ls命令
- roscore 运行ROS核心
- rosnode 
  - rosnode list 
  - rosnode clean_up
  - rosnode ping [-node ]
- rosrun [-package name] [- node name]
  - rosrun rqt_graph rqt_graph
  - rosrun rqt_plot rqt_plot