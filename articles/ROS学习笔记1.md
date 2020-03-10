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


### msg与srv文件
- msg文件用来描述message的数据类型
- srv用来描述服务(rosservice)的数据类型，比msg多了一个分隔符---和一个输出数据类型
  
#### 创建一个Message
- 在package下建立msg文件夹
  ``` 
  $ mkdir msg
  $ echo "int64 num" > msg/Num.msg
  ```
- 编辑package.xml，去掉以下两行的注释
  ```
  <build_depend>message_generation</build_depend>
  <exec_depend>message_runtime</exec_depend>
  ```
- 编辑CMakeLists.txt ，去掉以下注释：
  ```
  find_package(catkin REQUIRED COMPONENTS
   roscpp
   rospy
   std_msgs
   message_generation
  )

  catkin_package(
  ...
  CATKIN_DEPENDS message_runtime ...
  ...)

  add_message_files(
  FILES
  Num.msg
  )

  generate_messages(
  DEPENDENCIES
  std_msgs
  )

  ```

- 运行 `rosmsg show [message type]` 应该就能显示该Message


#### 创建一个service
- 前面与message一样，该注释的注释掉。注意：message_generation不仅可以用于生成message的代码，也可以用于生成srv的代码。
- 在编辑CMakeLists.txt时候，去掉以下注释（除了message去掉的那些）:
  ```
  add_service_files(
  FILES
  AddTwoInts.srv
  )
  ```
- 最后运行`rossrv show <service type>`应该就可以显示





### 权限问题解决方式：

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
  - rosrun rqt_console rqt_console
  - rosrun rqt_logger_level rqt_logger_level