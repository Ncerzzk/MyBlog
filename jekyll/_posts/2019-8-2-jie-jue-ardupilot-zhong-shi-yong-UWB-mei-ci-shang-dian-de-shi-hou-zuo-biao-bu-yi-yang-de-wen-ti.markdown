---
layout: post
title: 解决ardupilot中使用UWB每次上电的时候坐标不一样的问题
date: 2019-08-02 22:41:07 +0800
categories: 技术 飞控
issue_id: 57
---

在GCS_Common.cpp中，找到send_local_position函数，这个函数用来发送local_position给树莓派

将`get_relative_position_NED_home`修改为 `get_relative_position_NED_origin`

后者作用为获取当前的相对坐标，前者中调用了后者，并且减去了`_home`的偏移坐标，照理来说使用前者应该没问题，但实际使用中发现，他这个`_home`的偏移似乎有问题，因此干脆不用他这个，自己在后面减去偏移就行了

偏移可从`\libraries\AP_NavEKF3\AP_NavEKF3_RngBcnFusion.cpp`中获得，在`SelectRngBcnFusion`函数中，当beacon采集了100个点做了UWB系统中心位置估测后，估测出来的位置就是偏移，即

```
bcnPosOffsetNED.x = receiverPos.x - stateStruct.position.x;
bcnPosOffsetNED.y = receiverPos.y - stateStruct.position.y;
```

将这个偏移保存下来，然后减去就是了。这里用的办法比较粗暴，直接设置全局变量off_x,off_y；

```
off_x=bcnPosOffsetNED.x;
off_y=bcnPosOffsetNED.y;
```
注意，需在.cpp中定义，
然后在要减去的地方，
写上
```
extern float off_x,off_y;
```
减去即可。

为了不破坏ardupilot原本程序的封装，重构了一下。在AP\_NavEKF3\_core.cpp中，增加一个函数，把偏移量返回：
```
Vector3f NavEKF3_core::getBcnPosOffsetNED(){   // add by huang canming in 2019.4.17
	return bcnPosOffsetNED;
}
```

同理，在AP_NavEKF3.cpp中，也需要增加对应代码：
```
Vector3f NavEKF3::getBcnPosOffsetNED(){  // add by Huangcanming in 2019.4.17
	return core[primary].getBcnPosOffsetNED();
	
}
```
在各自相应的头文件中，应将函数声明为public

由此，在`get_relative_position_NED_origin`函数中，就可以调用这些函数来获取偏移，如：
```
    case EKF_TYPE3: {
			Vector3f off; // add by huang canming in 2019.4.17
            Vector2f posNE;
            float posD;
            if (EKF3.getPosNE(-1,posNE) && EKF3.getPosD(-1,posD)) {
                // position is valid
                off=EKF3.getBcnPosOffsetNED();   // add by huang canming in 2019.4.17
                vec.x = posNE.x-off.x;
                vec.y = posNE.y-off.y;
                vec.z = posD;
                return true;
            }
            return false;
        }
```








