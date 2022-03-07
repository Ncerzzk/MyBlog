---
layout: post
title: ArduPilot中beacon
date: 2019-03-13 14:45:31 +0800
categories: 技术 飞控
issue_id: 51
---
初始化过程：

在主文件中的`init_ardupilot`函数中进行各种传感器、串口、外设的初始化。

`init_beacon`初始化beacon设备，并在接下来
```ahrs.set_beacon(&g2.beacon);```

中将其绑定在ahrs对象中，因为ahrs解算姿态的时候，会用到beacon（如果有beacon设备的话）。

`init_beacon`的实现如下：
```
void AP_Beacon::init(void)
{
    if (_driver != nullptr) {
        // init called a 2nd time?
        return;
    }

    // create backend
    if (_type == AP_BeaconType_Pozyx) {
        _driver = new AP_Beacon_Pozyx(*this, serial_manager);
    } else if (_type == AP_BeaconType_Marvelmind) {
        _driver = new AP_Beacon_Marvelmind(*this, serial_manager);
    }
#if CONFIG_HAL_BOARD == HAL_BOARD_SITL
    if (_type == AP_BeaconType_SITL) {
        _driver = new AP_Beacon_SITL(*this);
    }
#endif
}
```
其中，_type变量在
```
AP_Beacon::AP_Beacon(AP_SerialManager &_serial_manager) :
    serial_manager(_serial_manager)
{
    AP_Param::setup_object_defaults(this, var_info);
}
```
中设置默认值，默认为0，也就是不使用beacon。

beacon的数据获取在主文件中，有一个任务：
```
 SCHED_TASK_CLASS(AP_Beacon,           &rover.g2.beacon,        update,         50,  200),
```
猜测其作用就是调用`Ap_Beacon`类的`update`函数，频率50hz
Ap_Beacon.update实现如下：
```
void AP_Beacon::update(void)
{
    if (!device_ready()) {
        return;
    }
    _driver->update();

    // update boundary for fence
    update_boundary_points();
}
```
`_driver`是`AP_Beacon_Backend`类的一个对象，带Backend的类是各种传感器的后端类，真正获取数据的是其子类，这里以`AP_Beacon_Pozyx`类为例:
```
void AP_Beacon_Pozyx::update(void)
{
    //主要内容就是从串口中读取Pozyx的数据包
    //然后调用AP_Beacon_Pozyx::parse_buffer将组合出
    //beacon_x beacon_y beacon_z 
    //vehicle_x vehicle_y vehicle_z
    //等数据
}
```
需要注意的是，pozyx传来的数据包有多种，分别是：
```
#define AP_BEACON_POZYX_MSGID_BEACON_CONFIG 0x02    // message contains anchor config information
#define AP_BEACON_POZYX_MSGID_BEACON_DIST   0x03    // message contains individual beacon distance
#define AP_BEACON_POZYX_MSGID_POSITION      0x04    // message contains vehicle position information
```
也就是基站(beacon）的xyz坐标，基站到标签的距离，标签的xyz坐标。



接下来看姿态解算的调用轨迹，从上到下，从外至里：
```
ahrs.update();
    update_EKF2();
        EKF2.UpdateFilter();
            core[i].UpdateFilter(statePredictEnabled[i]);
                SelectRngBcnFusion();
```
`SelectRngBcnFusion`函数的实现：
```
void NavEKF2_core::SelectRngBcnFusion()
{
    // read range data from the sensor and check for new data in the buffer
    readRngBcnData();

    // Determine if we need to fuse range beacon data on this time step
    if (rngBcnDataToFuse) {
        if (PV_AidingMode == AID_ABSOLUTE) {
            // Normal operating mode is to fuse the range data into the main filter
            FuseRngBcn();
        } else {
            // If we aren't able to use the data in the main filter, use a simple 3-state filter to estimte position only
            FuseRngBcnStatic();
        }
    }
}
```
`readRngBcnData()`主要是将beacon读取到的数据赋值到本地变量中，以便等一下进行EKF。
接下来，使用
`FuseRngBcn(); 或者 FuseRngBcnStatic();`对beacon进行EKF滤波；






