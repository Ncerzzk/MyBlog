# AutoPilotPi 使用说明 
ctime:2022-05-01 19:36:35 +0800|1651404995

标签（空格分隔）：技术  飞控  硬件

---

## SDNAND 烧写linux系统

- 基本原理可以参考挖坑网的这个帖子：https://whycan.com/t_2449.html
- 通过sunxi-fel将 uboot、os 和 rootfs 下载到V3s的内存中，然后通过uboot引导os 启动，在系统启动后，通过g_mass_storage 驱动，将sdnand 挂载为U盘
- 通过win32imager 或者 dd 将image烧写到sdnand中


### trouble shoot
- 如果出现image烧写到一般失败，则可能会出现无法再用上述操作进入FEL模式了，此时可以通过uboot 的mmc 命令，将前8K空间清除，这样上电时检测不到bios，还是会进入FEL模式
- 系统启动后，host PC上并没有出现盘符
  - 手动执行 echo peripheral > /sys/devices/platform/soc/1c19000.usb/musb-hdrc.1.auto/mode ， 切换OTG为外设模式（默认是host模式）

### 启动log参考

```
U-Boot SPL 2019.04-00743-g7d99406 (Apr 26 2019 - 02:24:09 -0400)
DRAM: 64 MiB
Trying to boot from FEL


U-Boot 2019.04-00743-g7d99406 (Apr 26 2019 - 02:24:09 -0400) Allwinner Technology

CPU:   Allwinner V3s (SUN8I 1681)
Model: Lichee Pi Zero
DRAM:  64 MiB
MMC:   mmc@01c0f000: 0
Loading Environment from FAT... Unable to use mmc 0:0... In:    serial@01c28000
Out:   serial@01c28000
Err:   serial@01c28000
Net:   No ethernet found.
starting USB...
No working controllers found
Hit any key to stop autoboot:  0
(FEL boot)
## Executing script at 41900000
## Loading init Ramdisk from Legacy Image at 41a00000 ...
   Image Name:   uInitrd
   Image Type:   ARM Linux RAMDisk Image (uncompressed)
   Data Size:    10271913 Bytes = 9.8 MiB
   Load Address: 00000000
   Entry Point:  00000000
   Verifying Checksum ... OK
## Flattened Device Tree blob at 41800000
   Booting using the fdt blob at 0x41800000
   Loading Ramdisk to 42434000, end 42dffca9 ... OK
   Loading Device Tree to 4242e000, end 42433e4f ... OK

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 4.13.16-licheepi-zero+ (root@ubuntu) (gcc version 4.8.4 (Ubuntu/Linaro 4.8.4-2ubuntu1~14.04.1)) #15 SMP Wed May 1 09:22:33 EDT 2019
[    0.000000] CPU: ARMv7 Processor [410fc075] revision 5 (ARMv7), cr=10c5387d
[    0.000000] CPU: div instructions available: patching division code
[    0.000000] CPU: PIPT / VIPT nonaliasing data cache, VIPT aliasing instruction cache
[    0.000000] OF: fdt: Machine model: Lichee Pi Zero with Dock
[    0.000000] Memory policy: Data cache writealloc
[    0.000000] psci: probing for conduit method from DT.
[    0.000000] psci: Using PSCI v0.1 Function IDs from DT
[    0.000000] percpu: Embedded 16 pages/cpu @c3fdf000 s33920 r8192 d23424 u65536
[    0.000000] Built 1 zonelists in Zone order, mobility grouping on.  Total pages: 16256
[    0.000000] Kernel command line: console=ttyS0,115200 panic=5 rootwait root=/dev/ram0 rdinit=/linuxrc earlyprintk rw
[    0.000000] PID hash table entries: 256 (order: -2, 1024 bytes)
[    0.000000] Dentry cache hash table entries: 8192 (order: 3, 32768 bytes)
[    0.000000] Inode-cache hash table entries: 4096 (order: 2, 16384 bytes)
[    0.000000] Memory: 45028K/65536K available (6144K kernel code, 236K rwdata, 1580K rodata, 1024K init, 253K bss, 20508K reserved, 0K cma-reserved, 0K highmem)
[    0.000000] Virtual kernel memory layout:
[    0.000000]     vector  : 0xffff0000 - 0xffff1000   (   4 kB)
[    0.000000]     fixmap  : 0xffc00000 - 0xfff00000   (3072 kB)
[    0.000000]     vmalloc : 0xc4800000 - 0xff800000   ( 944 MB)
[    0.000000]     lowmem  : 0xc0000000 - 0xc4000000   (  64 MB)
[    0.000000]     pkmap   : 0xbfe00000 - 0xc0000000   (   2 MB)
[    0.000000]     modules : 0xbf000000 - 0xbfe00000   (  14 MB)
[    0.000000]       .text : 0xc0008000 - 0xc0700000   (7136 kB)
[    0.000000]       .init : 0xc0900000 - 0xc0a00000   (1024 kB)
[    0.000000]       .data : 0xc0a00000 - 0xc0a3b360   ( 237 kB)
[    0.000000]        .bss : 0xc0a42808 - 0xc0a81dcc   ( 254 kB)
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] Hierarchical RCU implementation.
[    0.000000]  RCU event tracing is enabled.
[    0.000000]  RCU restricting CPUs from NR_CPUS=8 to nr_cpu_ids=1.
[    0.000000] RCU: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=1
[    0.000000] NR_IRQS: 16, nr_irqs: 16, preallocated irqs: 16
[    0.000000] arch_timer: cp15 timer(s) running at 24.00MHz (phys).
[    0.000000] clocksource: arch_sys_counter: mask: 0xffffffffffffff max_cycles: 0x588fe9dc0, max_idle_ns: 440795202592 ns
[    0.000007] sched_clock: 56 bits at 24MHz, resolution 41ns, wraps every 4398046511097ns
[    0.000019] Switching to timer-based delay loop, resolution 41ns
[    0.000211] clocksource: timer: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 79635851949 ns
[    0.000424] Console: colour dummy device 80x30
[    0.000460] Calibrating delay loop (skipped), value calculated using timer frequency.. 48.00 BogoMIPS (lpj=240000)
[    0.000476] pid_max: default: 32768 minimum: 301
[    0.000594] Mount-cache hash table entries: 1024 (order: 0, 4096 bytes)
[    0.000609] Mountpoint-cache hash table entries: 1024 (order: 0, 4096 bytes)
[    0.001183] CPU: Testing write buffer coherency: ok
[    0.001547] /cpus/cpu@0 missing clock-frequency property
[    0.001571] CPU0: thread -1, cpu 0, socket 0, mpidr 80000000
[    0.002005] Setting up static identity map for 0x40100000 - 0x40100060
[    0.002179] Hierarchical SRCU implementation.
[    0.002660] smp: Bringing up secondary CPUs ...
[    0.002674] smp: Brought up 1 node, 1 CPU
[    0.002683] SMP: Total of 1 processors activated (48.00 BogoMIPS).
[    0.002689] CPU: All CPU(s) started in HYP mode.
[    0.002694] CPU: Virtualization extensions available.
[    0.003423] devtmpfs: initialized
[    0.006434] VFP support v0.3: implementor 41 architecture 2 part 30 variant 7 rev 5
[    0.006713] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
[    0.006741] futex hash table entries: 256 (order: 2, 16384 bytes)
[    0.006914] pinctrl core: initialized pinctrl subsystem
[    0.007747] random: get_random_u32 called from bucket_table_alloc+0xf0/0x250 with crng_init=0
[    0.007882] NET: Registered protocol family 16
[    0.008303] DMA: preallocated 256 KiB pool for atomic coherent allocations
[    0.009344] hw-breakpoint: found 5 (+1 reserved) breakpoint and 4 watchpoint registers.
[    0.009360] hw-breakpoint: maximum watchpoint size is 8 bytes.
[    0.021525] SCSI subsystem initialized
[    0.021811] usbcore: registered new interface driver usbfs
[    0.021881] usbcore: registered new interface driver hub
[    0.021975] usbcore: registered new device driver usb
[    0.022227] Linux video capture interface: v2.00
[    0.022272] pps_core: LinuxPPS API ver. 1 registered
[    0.022280] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
[    0.022301] PTP clock support registered
[    0.022510] Advanced Linux Sound Architecture Driver Initialized.
[    0.024293] clocksource: Switched to clocksource arch_sys_counter
[    0.033982] NET: Registered protocol family 2
[    0.034659] TCP established hash table entries: 1024 (order: 0, 4096 bytes)
[    0.034694] TCP bind hash table entries: 1024 (order: 1, 8192 bytes)
[    0.034718] TCP: Hash tables configured (established 1024 bind 1024)
[    0.034845] UDP hash table entries: 256 (order: 1, 8192 bytes)
[    0.034891] UDP-Lite hash table entries: 256 (order: 1, 8192 bytes)
[    0.035101] NET: Registered protocol family 1
[    0.035522] Unpacking initramfs...
[    0.752900] Freeing initrd memory: 10032K
[    0.754877] workingset: timestamp_bits=30 max_order=14 bucket_order=0
[    0.762639] jffs2: version 2.2. (NAND) (SUMMARY)  © 2001-2006 Red Hat, Inc.
[    0.764214] random: fast init done
[    0.767227] Block layer SCSI generic (bsg) driver version 0.4 loaded (major 249)
[    0.767250] io scheduler noop registered
[    0.767257] io scheduler deadline registered
[    0.767489] io scheduler cfq registered (default)
[    0.767501] io scheduler mq-deadline registered
[    0.767507] io scheduler kyber registered
[    0.771768] sun8i-v3s-pinctrl 1c20800.pinctrl: initialized sunXi PIO driver
[    0.835944] Serial: 8250/16550 driver, 8 ports, IRQ sharing disabled
[    0.839234] console [ttyS0] disabled
[    0.859503] 1c28000.serial: ttyS0 at MMIO 0x1c28000 (irq = 36, base_baud = 1500000) is a U6_16550A
[    1.436618] console [ttyS0] enabled
[    1.442798] libphy: Fixed MDIO Bus: probed
[    1.447484] dwmac-sun8i 1c30000.ethernet: PTP uses main clock
[    1.453279] dwmac-sun8i 1c30000.ethernet: No regulator found
[    1.459056] dwmac-sun8i 1c30000.ethernet: Will use internal PHY
[    1.565195] dwmac-sun8i 1c30000.ethernet: EMAC reset timeout
[    1.570934] dwmac-sun8i: probe of 1c30000.ethernet failed with error -12
[    1.577945] ehci_hcd: USB 2.0 'Enhanced' Host Controller (EHCI) Driver
[    1.584520] ehci-platform: EHCI generic platform driver
[    1.590013] ehci-platform 1c1a000.usb: EHCI Host Controller
[    1.595678] ehci-platform 1c1a000.usb: new USB bus registered, assigned bus number 1
[    1.603585] ehci-platform 1c1a000.usb: irq 26, io mem 0x01c1a000
[    1.634296] ehci-platform 1c1a000.usb: USB 2.0 started, EHCI 1.00
[    1.641459] hub 1-0:1.0: USB hub found
[    1.645395] hub 1-0:1.0: 1 port detected
[    1.649816] ohci_hcd: USB 1.1 'Open' Host Controller (OHCI) Driver
[    1.656108] ohci-platform: OHCI generic platform driver
[    1.661686] ohci-platform 1c1a400.usb: Generic Platform OHCI controller
[    1.668412] ohci-platform 1c1a400.usb: new USB bus registered, assigned bus number 2
[    1.676342] ohci-platform 1c1a400.usb: irq 27, io mem 0x01c1a400
[    1.749338] hub 2-0:1.0: USB hub found
[    1.753151] hub 2-0:1.0: 1 port detected
[    1.758263] usbcore: registered new interface driver cdc_acm
[    1.763927] cdc_acm: USB Abstract Control Model driver for USB modems and ISDN adapters
[    1.772136] usbcore: registered new interface driver usb-storage
[    1.778317] usbcore: registered new interface driver usbserial
[    1.784182] usbcore: registered new interface driver usbserial_generic
[    1.790795] usbserial: USB Serial support registered for generic
[    1.796865] usbcore: registered new interface driver ch341
[    1.802377] usbserial: USB Serial support registered for ch341-uart
[    1.808697] usbcore: registered new interface driver cp210x
[    1.814311] usbserial: USB Serial support registered for cp210x
[    1.820273] usbcore: registered new interface driver ftdi_sio
[    1.826066] usbserial: USB Serial support registered for FTDI USB Serial Device
[    1.833475] usbcore: registered new interface driver pl2303
[    1.839120] usbserial: USB Serial support registered for pl2303
[    1.845105] usbcore: registered new interface driver usb_serial_simple
[    1.851677] usbserial: USB Serial support registered for carelink
[    1.857845] usbserial: USB Serial support registered for zio
[    1.863531] usbserial: USB Serial support registered for funsoft
[    1.869609] usbserial: USB Serial support registered for flashloader
[    1.876006] usbserial: USB Serial support registered for google
[    1.881946] usbserial: USB Serial support registered for vivopay
[    1.887991] usbserial: USB Serial support registered for moto_modem
[    1.894297] usbserial: USB Serial support registered for novatel_gps
[    1.900670] usbserial: USB Serial support registered for hp4x
[    1.906451] usbserial: USB Serial support registered for suunto
[    1.912390] usbserial: USB Serial support registered for siemens_mpi
[    1.919977] mousedev: PS/2 mouse device common for all mice
[    1.926446] input: 1c22800.lradc as /devices/platform/soc/1c22800.lradc/input/input0
[    1.935359] sun6i-rtc 1c20400.rtc: rtc core: registered rtc-sun6i as rtc0
[    1.942153] sun6i-rtc 1c20400.rtc: RTC enabled
[    1.946778] i2c /dev entries driver
[    1.951762] input: ns2009_ts as /devices/platform/soc/1c2ac00.i2c/i2c-0/0-0048/input/input1
[    1.960947] usbcore: registered new interface driver uvcvideo
[    1.966763] USB Video Class driver (1.1.1)
[    1.971536] sunxi-wdt 1c20ca0.watchdog: Watchdog enabled (timeout=16 sec, nowayout=0)
[    2.034341] sunxi-mmc 1c0f000.mmc: base:0xc48d5000 irq:23
[    2.091402] mmc0: host does not support reading read-only switch, assuming write-enable
[    2.099498] sunxi-mmc 1c10000.mmc: base:0xc48d9000 irq:24
[    2.106028] usbcore: registered new interface driver usbhid
[    2.111604] usbhid: USB HID core driver
[    2.116186] mmc0: new high speed SD card at address 1388
[    2.122170] mmcblk0: mmc0:1388 CS004 482 MiB
[    2.128738] sun4i-codec 1c22c00.codec: ASoC: /soc/codec-analog@01c23000 not registered
[    2.136787] sun4i-codec 1c22c00.codec: Failed to register our card
[    2.144759] NET: Registered protocol family 17
[    2.149353] Registering SWP/SWPB emulation handler
[    2.162689] usb_phy_generic usb_phy_generic.0.auto: usb_phy_generic.0.auto supply vcc not found, using dummy regulator
[    2.174108] musb-hdrc musb-hdrc.1.auto: MUSB HDRC host driver
[    2.179955] musb-hdrc musb-hdrc.1.auto: new USB bus registered, assigned bus number 3
[    2.189024] hub 3-0:1.0: USB hub found
[    2.192879] hub 3-0:1.0: 1 port detected
[    2.200407] sun4i-codec 1c22c00.codec: Codec <-> 1c22c00.codec mapping ok
[    2.209193] sun6i-rtc 1c20400.rtc: setting system clock to 1970-01-01 00:04:32 UTC (272)
[    2.217654] vcc5v0: disabling
[    2.220633] ALSA device list:
[    2.223598]   #0: V3s Audio Codec
[    2.228870] Freeing unused kernel memory: 1024K
mount: mounting tmpfs on /dev/shm failed: Invalid argument
mount: mounting tmpfs on /tmp failed: Invalid argument
mount: mounting tmpfs on /run failed: Invalid argument
can't open /dev/null: No such file or directory
can't open /dev/null: No such file or directory
can't open /dev/null: No such file or directory
can't open /dev/null: No such file or directory
Starting logging: OK
Starting mdev...
Initializing random number generator... done.
Starting network: OK
[    3.445705] Mass Storage Function, version: 2009/09/11
[    3.450868] LUN: removable file: (no medium)
[    3.455503] LUN: removable file: /dev/mmcblk0
[    3.459865] Number of LUNs=1
[    3.495064] g_mass_storage gadget: Mass Storage Gadget, version: 2009/09/11
[    3.502043] g_mass_storage gadget: userspace failed to provide iSerialNumber
[    3.509196] g_mass_storage gadget: g_mass_storage ready
# echo peripheral > /sys/devices/platform/
Fixed MDIO bus.0/        regulatory.0/            uevent
alarmtimer/              serial8250/              usb_phy_generic.0.auto/
power/                   snd-soc-dummy/           vcc3v0/
psci/                    soc/                     vcc3v3/
reg-dummy/               timer/                   vcc5v0/
# echo peripheral > /sys/devices/platform/soc/1c
1c00000.syscon/          1c1a000.usb/             1c22800.lradc/
1c02000.dma-controller/  1c1a400.usb/             1c22c00.codec/
1c0f000.mmc/             1c20400.rtc/             1c23000.codec-analog/
1c10000.mmc/             1c20800.pinctrl/         1c28000.serial/
1c19000.usb/             1c20c00.timer/           1c2ac00.i2c/
1c19400.phy/             1c20ca0.watchdog/        1c30000.ethernet/
# echo peripheral > /sys/devices/platform/soc/1c19
1c19000.usb/  1c19400.phy/
# echo peripheral > /sys/devices/platform/soc/1c19
1c19000.usb/  1c19400.phy/
# echo peripheral > /sys/devices/platform/soc/1c19000.usb/musb-hdrc.1.auto/mode
# [   52.706865] phy phy-1c19400.phy.0: Changing dr_mode to 2
[   53.924341] musb-hdrc musb-hdrc.1.auto: VBUS_ERROR in b_idle (98, VALID), retry #0, port1 00000100
[   54.201906] g_mass_storage gadget: high-speed config #1: Linux File-Backed Storage
[   74.537604] random: crng init done

```