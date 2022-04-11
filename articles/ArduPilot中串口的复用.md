# ArduPilot中串口的复用
ctime:2019-03-13 14:45:17 +0800|1552459517

标签（空格分隔）： 技术 硬件 飞控

---
ardupilot中因为项目太庞大，初看串口的复用很是疑惑。

仔细一看的话，其实人家的实现挺有技巧性的。

所有需要从串口中读取数据的设备，一般要实现一个Backend类（后端类）的子类，用于与底层打交道。如`AP_Beacon_Pozyx`继承自`AP_Beacon_Backend`。

同时，这个底层设备类的构造函数中，还要传入一个`AP_SerialManager`类的对象的引用，实际上使用的时候就是传入全局的串口管理对象

```c
AP_SerialManager serial_manager; //定义在rover.h中
```

`AP_SerialManger` 负责管理整机使用的所有串口，其初始化是这样的：

```
void AP_SerialManager::init()
{
    // initialise pointers to serial ports
    state[1].uart = hal.uartC;  // serial1, uartC, normally telem1
    state[2].uart = hal.uartD;  // serial2, uartD, normally telem2
    state[3].uart = hal.uartB;  // serial3, uartB, normally 1st GPS
    state[4].uart = hal.uartE;  // serial4, uartE, normally 2nd GPS
    state[5].uart = hal.uartF;  // serial5
    state[6].uart = hal.uartG;  // serial6

    if (state[0].uart == nullptr) {
        init_console();   // 初始化serial0给console使用
    }
    
    // initialise serial ports
    for (uint8_t i=1; i<SERIALMANAGER_NUM_PORTS; i++) {
        // 接下来根据每个串口的宏定义（波特率、协议等），对每个串口进行设置。
        case SerialProtocol_Console:
        case SerialProtocol_MAVLink:
        case SerialProtocol_MAVLink2:
            state[i].uart->begin(map_baudrate(state[i].baud),                           AP_SERIALMANAGER_MAVLINK_BUFSIZE_RX, AP_SERIALMANAGER_MAVLINK_BUFSIZE_TX);
        break;
    }
}
```

回到刚刚说的要用到串口的设备，在初始化函数中，因为已经传入了全局的串口管理对象，此时只要在串口管理对象中搜索与当前这个设备对应的协议即可。

一个pozyx的例子：

```
AP_Beacon_Pozyx::AP_Beacon_Pozyx(AP_Beacon &frontend, AP_SerialManager &serial_manager) :
    AP_Beacon_Backend(frontend),
    linebuf_len(0)
{
    uart = serial_manager.find_serial(AP_SerialManager::SerialProtocol_Beacon, 0);
    if (uart != nullptr) {
        uart->begin(serial_manager.find_baudrate(AP_SerialManager::SerialProtocol_Beacon, 0));
    }
}
```

uart是一个指向串口对象的指针，如果找到了响应的协议，那么uart即指向对应串口，否则uart的默认值是nullptr。

在各个设备的update函数中，读取串口数据之前，需要先检查以下uart是否为空指针，如果为空指针直接返回。

这样的话，整个项目对串口的管理就很灵活，当因为某种需要修改某个串口为它用之时，只需在SerialManger文件，及相关宏定义中，修改某个串口对应的协议即可，然后新设备即可使用这个串口。旧设备也不会再读取这个串口，因为对旧设备而言，此时uart已经是空指针了，在update中会直接返回，不会出现两个设备同时读取一个串口的情况。
