# Ardupilot中新增beacon设备
ctime:2019-04-02 16:15:52 +0800|1554192952

标签（空格分隔）： 技术

---

ardupilot的串口与beacon大致情况在之前都写过了。这里不再赘述，直接写我新增的INF（无穷未来）的驱动手册吧。

### 加入驱动文件
在AP_Beacon文件夹中，加入AP_Beacon_Frompi.cpp 及相应的头文件。

### 增加Beacon设备枚举
在AP_Beacon.h文件中，增加AP_BeaconType的枚举成员，这里命名为了AP_BeaconType_INF，值为3。

在var_info数组中，修改_TYPE常量的值，改为3，即使用AP_BeaconType_INF。

_LATITUDE 和 _LONGITUDE 可以在这里直接设置，也可以在MP里设置。


### 增加串口协议枚举
在AP_SerialManager.h中，增加SerialProtocol的枚举成员，这里命名为SerialProtocol_UWB_INF，值为20。

在在AP_SerialManager.cpp中init()函数下，增加新枚举成员的case：
```
				case SerialProtocol_UWB_INF: // add by huangcanming in 2019.3.13
				case SerialProtocol_UWB: // ad by huangcanming in 2019.3.12 ,this is just for test
					state[i].uart->begin(map_baudrate(state[i].baud),
                	               256,
                	               128);
					break;
```
					
### 指定INF使用的串口
在AP_SerialManager的var_info数组初始化中，修改串口3的协议为SerialProtocol_UWB_INF，波特率为921。

串口3是原GPS的使用串口，因为用UWB代替GPS了，因此直接替代掉。

各个串口的说明：
```
    state[1].uart = hal.uartC;  // serial1, uartC, normally telem1
    state[2].uart = hal.uartD;  // serial2, uartD, normally telem2
    state[3].uart = hal.uartB;  // serial3, uartB, normally 1st GPS
    state[4].uart = hal.uartE;  // serial4, uartE, normally 2nd GPS
    state[5].uart = hal.uartF;  // serial5, DEBUG
```
    
### 其他参数设置
- 设置初始经纬度
- AHRS_EKF_TYPE 设置为3 使用EKF3
- EK3_ENABLE 设置为1
- BCN_ORIENT_YAW 必须设置，否则坐标系是倾斜的，走直线变成斜线。
设置方式：
```
One way to capture this value is to stand at the origin holding the vehicle so that it’s nose points towards the second beacon. Read the vehicle’s heading from the HUD and enter this value into
```


					




