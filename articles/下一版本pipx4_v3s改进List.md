# 下一版本pipx4_v3s改进List
ctime:2022-03-16 00:31:33 +0800|1647361893

标签（空格分隔）： 技术 硬件

---

- 去掉 SPI NAND FLASH （容量太小）
- 在sdc1 的接口上增加上拉电阻
- 增加FPGA到V3s的几个引脚连接，使V3s能够控制FPGA的Reset等功能
- 考虑使用SD NAND FLash 来代替SD卡 如：CSNP1GCR01