---
layout: post
title: PX4的传感器数据读取流程
date: 2022-01-29 09:40:51 +0800
categories:  飞控
issue_id: 155
---

因为之前自己整了个PX4的飞控，但是IMU用的ICM20600，目前PX4还不支持（实际上只是修改个WHO AM I的事），没办法只能自己动手。

PX4的架构图还是挺清晰的，见：https://dev.px4.io/v1.11_noredirect/zh/concept/architecture.html

但是从架构图中，我还是看不出一个它是怎么读取一个特定的传感器的数据，并通过uORB发布出去的。那就自己看吧，首先比较熟悉的地方入手，如IMU，找到
一个眼熟的IMU开始看，如ICM20602。

首先看一下构造函数：
```cpp
ICM20602::ICM20602(const I2CSPIDriverConfig &config) :
	SPI(config),
	I2CSPIDriver(config),
	_drdy_gpio(config.drdy_gpio),
	_px4_accel(get_device_id(), config.rotation),
	_px4_gyro(get_device_id(), config.rotation)
{
	if (_drdy_gpio != 0) {
		_drdy_missed_perf = perf_alloc(PC_COUNT, MODULE_NAME": DRDY missed");
	}

	ConfigureSampleRate(_px4_gyro.get_max_rate_hz());
}
```

其中`SPI` 和`I2CSPIDriver`应该跟更底层的传感器总线通信有关，但我们这里关注的是他如何上报的，因此这部分先略过。`_drdy_gpio`也不知道干嘛的，先跳过。
主要看一下下面，`_px4_accel`和`_px4_gyro`的初始化中出现了`device_id`，而我们知道uORB订阅和发布是需要有个ID的，因此这个很可能就跟uORB有关。

继续看一下`_px4_accel`和`_px4_gyrp`是什么。

```cpp
	PX4Accelerometer _px4_accel;
	PX4Gyroscope _px4_gyro;
```

一个是加速度计类一个是陀螺仪类，随便找个进去看看，二者在上报这个流程上应该区别不大。

```cpp
PX4Gyroscope::PX4Gyroscope(uint32_t device_id, enum Rotation rotation) :
	_device_id{device_id},
	_rotation{rotation}
{
	// advertise immediately to keep instance numbering in sync
	_sensor_pub.advertise();

	param_get(param_find("IMU_GYRO_RATEMAX"), &_imu_gyro_rate_max);
}
```

真相呼之欲出，`_sensor_pub`继续看看是啥：

```cpp
uORB::PublicationMulti<sensor_gyro_s> _sensor_pub{ORB_ID(sensor_gyro)};
```
其中`sensor_gyro_s`和`sensor_gyro`找了半天，没找到定义，后来发现原来使uORB中的msg，编译的时候会将这些msg生成cpp和hpp文件。

```cpp
uint64 timestamp          # time since system start (microseconds)
uint64 timestamp_sample

uint32 device_id          # unique device ID for the sensor that does not change between power cycles

float32 x                 # angular velocity in the FRD board frame X-axis in rad/s
float32 y                 # angular velocity in the FRD board frame Y-axis in rad/s
float32 z                 # angular velocity in the FRD board frame Z-axis in rad/s

float32 temperature       # temperature in degrees Celsius

uint32 error_count

uint8 samples             # number of raw samples that went into this message

uint8 ORB_QUEUE_LENGTH = 8
```

好了，所以调用链就很明显了，每个传感器如i2cm20602的类中，有个PX4Gyroscope的对象，PX4Gyroscope中则有一个PublicationMulti的对象，通过该对象
完成数据的发布。

还有一个问题，sensors模块号称能监控各个传感器的状态，来看看它的实现。

```cpp
Sensors::Sensors(bool hil_enabled) :
	ModuleParams(nullptr),
	ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::nav_and_controllers),
	_hil_enabled(hil_enabled),
	_loop_perf(perf_alloc(PC_ELAPSED, "sensors")),
	_voted_sensors_update(hil_enabled, _vehicle_imu_sub)
{
	/* Differential pressure offset */
	_parameter_handles.diff_pres_offset_pa = param_find("SENS_DPRES_OFF");
#ifdef ADC_AIRSPEED_VOLTAGE_CHANNEL
	_parameter_handles.diff_pres_analog_scale = param_find("SENS_DPRES_ANSC");
#endif /* ADC_AIRSPEED_VOLTAGE_CHANNEL */

	_parameter_handles.air_cmodel = param_find("CAL_AIR_CMODEL");
	_parameter_handles.air_tube_length = param_find("CAL_AIR_TUBELEN");
	_parameter_handles.air_tube_diameter_mm = param_find("CAL_AIR_TUBED_MM");

	param_find("SYS_FAC_CAL_MODE");

	// Parameters controlling the on-board sensor thermal calibrator
	param_find("SYS_CAL_TDEL");
	param_find("SYS_CAL_TMAX");
	param_find("SYS_CAL_TMIN");

	_airspeed_validator.set_timeout(300000);
	_airspeed_validator.set_equal_value_threshold(100);

	_vehicle_acceleration.Start();
	_vehicle_angular_velocity.Start();
}
```

关注一下最后俩句，我们对IMU比较熟悉，从这里来看吧

```cpp
	VehicleAcceleration	_vehicle_acceleration;
	VehicleAngularVelocity	_vehicle_angular_velocity;
```

```cpp
VehicleAngularVelocity::VehicleAngularVelocity() :
	ModuleParams(nullptr),
	ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::rate_ctrl)
{
}
```

```cpp
bool VehicleAngularVelocity::Start()
{
	// force initial updates
	ParametersUpdate(true);

	// sensor_selection needed to change the active sensor if the primary stops updating
	if (!_sensor_selection_sub.registerCallback()) {
		PX4_ERR("sensor_selection callback registration failed");
		return false;
	}

	if (!SensorSelectionUpdate(true)) {
		_sensor_sub.registerCallback();
	}

	return true;
}
```

VehicleAngularVelocity 还有其他的函数，比较复杂就不贴在这里了，看起来这个类应该是比陀螺仪读取更顶层一点，即通过传感器数据来计算飞行器的角速度。

而Sensors下还有个VehicleIMU，会在Run函数中初始化一次。这个应该是我们要找的，

```cpp
void Sensors::Run()
{
	// run once
	if (_last_config_update == 0) {
		InitializeVehicleAirData();
		InitializeVehicleIMU();
		InitializeVehicleGPSPosition();
		InitializeVehicleMagnetometer();
		_voted_sensors_update.init(_sensor_combined);
		parameter_update_poll(true);
	}
    ...
```

```cpp
void Sensors::InitializeVehicleIMU()
{
	// create a VehicleIMU instance for each accel/gyro pair
	for (uint8_t i = 0; i < MAX_SENSOR_COUNT; i++) {
		if (_vehicle_imu_list[i] == nullptr) {

			uORB::Subscription accel_sub{ORB_ID(sensor_accel), i};
			sensor_accel_s accel{};
			accel_sub.copy(&accel);

			uORB::Subscription gyro_sub{ORB_ID(sensor_gyro), i};
			sensor_gyro_s gyro{};
			gyro_sub.copy(&gyro);

			if (accel.device_id > 0 && gyro.device_id > 0) {
				// if the sensors module is responsible for voting (SENS_IMU_MODE 1) then run every VehicleIMU in the same WQ
				//   otherwise each VehicleIMU runs in a corresponding INSx WQ
				const bool multi_mode = (_param_sens_imu_mode.get() == 0);
				const px4::wq_config_t &wq_config = multi_mode ? px4::ins_instance_to_wq(i) : px4::wq_configurations::INS0;

				VehicleIMU *imu = new VehicleIMU(i, i, i, wq_config);

				if (imu != nullptr) {
					// Start VehicleIMU instance and store
					if (imu->Start()) {
						_vehicle_imu_list[i] = imu;

					} else {
						delete imu;
					}
				}

			} else {
				// abort on first failure, try again later
				return;
			}
		}
	}
}
```

这个初始化不是很复杂，主要是通过device_id来判断当前ID号的IMU是否有效，比如我们可能只接了一个IMU，而这里会遍历4个IMU。

那么VehicleIMU是如何判断当前的IMU有效呢？

```cpp
VehicleIMU::VehicleIMU(int instance, uint8_t accel_index, uint8_t gyro_index, const px4::wq_config_t &config) :
	ModuleParams(nullptr),
	ScheduledWorkItem(MODULE_NAME, config),
	_sensor_accel_sub(ORB_ID(sensor_accel), accel_index),
	_sensor_gyro_sub(this, ORB_ID(sensor_gyro), gyro_index),
	_instance(instance)
{
	_imu_integration_interval_us = 1e6f / _param_imu_integ_rate.get();

	_accel_integrator.set_reset_interval(_imu_integration_interval_us);
	_accel_integrator.set_reset_samples(sensor_accel_s::ORB_QUEUE_LENGTH);

	_gyro_integrator.set_reset_interval(_imu_integration_interval_us);
	_gyro_integrator.set_reset_samples(sensor_gyro_s::ORB_QUEUE_LENGTH);

#if defined(ENABLE_LOCKSTEP_SCHEDULER)
	// currently with lockstep every raw sample needs a corresponding vehicle_imu publication
	_sensor_gyro_sub.set_required_updates(1);
#else
	// schedule conservatively until the actual accel & gyro rates are known
	_sensor_gyro_sub.set_required_updates(sensor_gyro_s::ORB_QUEUE_LENGTH / 2);
#endif

	// advertise immediately to ensure consistent ordering
	_vehicle_imu_pub.advertise();
	_vehicle_imu_status_pub.advertise();
}
```

通过