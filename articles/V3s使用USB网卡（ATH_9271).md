# V3s使用USB网卡_AR_9271
ctime:2022-02-27 11:58:11 +0800|1645934291

标签（空格分隔）： 技术 硬件

---

首先在kernel 的config 文件中加入:

```kconfig
CONFIG_ATH9K=m
CONFIG_ATH9K_DEBUGFS=y
CONFIG_ATH9K_STATION_STATISTICS=y
CONFIG_ATH9K_WOW=y
CONFIG_ATH9K_CHANNEL_CONTEXT=y
CONFIG_ATH9K_HTC=m
CONFIG_ATH9K_HTC_DEBUGFS=y
```
重新编译内核。记得将内核模块一并拿出来，使用
```make modules_install INSTALL_MOD_PATH=$rootfs路径```

这只是kernel的驱动接口，还需要下载AR9271的驱动固件（firmware）htc_9271.fw：https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/

下载之后可以放到rootfs的 /lib/firmware 下。

系统启动可以，使用命令启用usb网卡：

```shell
modprobe ath9k_htc.ko
ifconfig wlan0 up
```

为了顺利连上wifi，还需要在rootfs中安装wpa_supplicant（或者iw,但是iw不支持wpa加密的网络）来配置wifi

- 使用wpa_passphrase生成配置文件:`wpa_passphrase test_wifi 12345678 > /etc/wpa_supplicant/test.conf`
- 启动wpa_supplicant`wpa_supplicant -D driver -i wlan0 -c /etc/wpa_supplicant.conf -B`
  - 其中-D 代表驱动程序名称，可以省略
  - -B 后台运行
  - -i 代表接口名称
  - -c 配置文件名




