---
layout: post
title: 3D打印机的入门与维护 
date: 2020-11-04 14:54:47 +0800
categories: 技术 硬件
issue_id: 142
---

队里的3D打印机修好了，这里总结一下3D打印机的一些入门知识和常见问题的解决方式，当然，我折腾3D打印机的时间也不久，大家参考着看。

希望大家都能尽量掌握3D打印机的用法。3D打印机需要常常使用和维护，否则精度下降严重，打印质量也会很差。不要担心把打印机用坏，用坏了修就行了。

另外，从队里机构的角度来讲，不要太依赖打印件，重要机构该送出去加工就送出去加工，该雕刻雕刻。机构设计要用心，不要指望机构没设计好，想用3D打印打印点小机构补救来耍小聪明。

### 软件与上位机

我们的打印机是优造智能的，但由于内部的固件实际上是Marlin开源固件，因此我们可以使用Cura来控制，而不是用优造智能的修改版。Cura在官网可以下载。

安装完毕后，可以在设置中，将语言修改为简体中文。

在Cura中增加打印机，队里的打印机是三角洲结构的，英文名称是delta，在打印机列表中找到delta printer。

设置打印机的长宽为155，高度为205，其他设置可以保持不变（喷头直径0.4，材料直径1.75mm)

Marlin固件与电脑的连接使用CH340串口芯片，因此电脑需安装CH340驱动。



### FDM

FDM指熔融沉积，3D打印机大多都是这种成形方式。

其原理：加热喷头在计算机的控制下，根据产品零件的截面轮廓信息，作X-Y平面运动，热塑性丝状材料由供丝机构送至热熔喷头，并在喷头中加热和熔化成半液态，然后被挤压出来，有选择性的涂覆在工作台上，快速冷却后形成一层大约0.127mm厚的薄片轮廓。一层截面成型完成后工作台下降一定高度，再进行下一层的熔覆，好像一层层"画出"截面轮廓，如此循环，最终形成三维产品零件。(复制自百科)

当然，也有其他成型方式，如光固化等。但光固化的打印机一般都较贵。

### PLA冷打

所谓冷打，与热打相对应。热打是通过热床，来保证模型底层的温度在60℃左右（对于PLA而言），来防止翘边。否则由于材料的热胀冷缩特性，翘边常常会发生。
由于很多3D打印机并没有加配热床，因此渐渐发明了冷打的技术。通过一些方式：

- 在底面涂固体胶
- 使用软平台
- 适当压低
- 首层慢速打印
  
等等，也可以取得不错的效果。具体如何防止翘边在后面讨论。

### 三角洲
三角洲又称为并联臂，是现在市面上很常见的一种3D打印机结构类型，采用的是并联式运动结构，上往下看机器大致呈一个三角形。

三角洲基本特点：

- 远程挤出（为了最大地减少喷头的重量，减少移动惯性）
- 并联臂，打圆会比XY型平面移动更精确。
- 打印速度快
- 空间利用率较低，可打较高的器件，底面积较大的不好打
- 调平较为麻烦

### 喷嘴直径、层高

喷嘴直径现在默认是0.4mm，相当于打印机突出的丝宽度就是0.4mm。而层高则表示3D打印每一层的高度，层高调小，意味着相同高度下，层数变多，打印件也会更扎实，当然，速度就慢了。

0.4mm的喷嘴可调的层高在0.1mm-0.3mm左右。使用更小的喷嘴可以提高XY的精度，但是打印速度就会相应变慢，Z轴精度则由层高控制。

### 调平

打印机需要将平台调平，以防止有些地方高，有些地方低，打出来材料成型不均匀，且容易翘边。队里打印机的调平方式：

- 将XYZ回归零点，此时（X0，Y0，Z255）
- 在CURA上，或者用显示屏旋钮，将Z下降至0.3（为什么是0.3？因为CURA生成的G代码就是从0.3高度处开始打的，具体可以随便打开一个生成的G代码看看）
- 平台由三个螺栓控制调平，依次控制XY将喷头移动到距离三个螺栓较近的地方，然后放上A4纸，调节与喷头最近的螺栓，使A4纸可以在平台和喷头间自由移动，并且有一点摩擦力
- 三个地方调整完毕后，将喷头移植中间，继续放上A4纸，调整三个螺栓，使A4纸可以自由移动+有一点摩擦力
  

### 切片

我们通过SW保存的格式为STL文件，该文件仅通过多面体来定义模型。对于3D打印机而言，它并不能识别这么复杂的东西，它只能识别G代码，即告诉它每个步进电机该走多远距离。

因此，当我们输出STL之后，需要使用切片软件（如CURA）来对模型进行切片，从而转化3D打印机认识的G代码。G代码有多种，3D打印机常用的G代码一般是Marlin格式的。Marlin是一个
3D打印机的开源固件，现在除了支持3D打印机以外，也支持CNC等。

下面介绍一些常用的切片设置：


#### 支撑
  
对于打印件，我们一般根据3D打印机的成形方式来设计，以最大可能的减少支撑。当然，很多时候由于模型的关系，不得不加支撑
支撑分为两种，一种是普通支撑，一种是树形支撑。

普通支撑与打印平常的层差不多，只是打得比较快，比较马虎，毕竟不需要精度，同时切片软件会在支撑与实际模型中增加一点距离，方便打印完毕之后拆下支撑。
但是由于种种原因，经常这个普通支撑非常难拆，导致一用力就可能破坏模型。

另一种支撑是树形支撑，树形支撑顾名思义，就是树枝树杈状的支撑。使用树形支撑可以最大程度的减小支撑面积，加快打印速度，更重要的是树形支撑比较好拆。

CURA中开启树形支撑的方式，右上角打印设置中，点击自定义，搜索 “树形”，然后在 实验室（即实验功能） 中，开启树形支撑，然后就可以在支撑类型中选择树形了。

#### 模型摆放

导入STL之后，可以通过Cura左边的按钮来控制模型哪个面作为底面，找到某个角度，使之生成的支撑最少，一般就是最佳角度。


#### 附着

如果模型与底面的接触面积太小，打印过程中可能会由于粘的不牢，导致模型被喷头粘走（毕竟喷头温度200℃左右，可以融化材料）。勾选附着之后，切片软件会自动在首层生成相应的附着，
增大接触面积 。等打印结束后，可以将附着拆掉。（与支撑有相似之处）

#### 水平拓展

由于FDM技术的特性，打印出来的孔常常会比设计图上的小。可以通过在设计图上把孔改大，但这样太麻烦，不同的3D打印机，不同的材料，要扩大的尺寸可能不一样。
而且可能有时候也会忘记，导致装配时出现各种问题。

可以在切片软件中设置水平拓展，设置为负值，如-0.1mm，这样打印出来的孔就会比不设置水平拓展的值稍大。一般设置为-0.1或者-0.2左右。

### Brim

一般的切片软件都会有默认设置的Brim，在模型外围生成一小段边沿，用于检查平台与喷头的距离、喷头吐丝是否正常、模型粘连情况等等。由于打印机刚加热完毕后，喷头前端可能还未满，需要挤出机再往里挤出一点材料，才能正常出丝。如果没有Brim直接开始打印，就会导致模型刚开始的一些地方没有正常吐丝。

在CURA中，可以设置Brim的最小长度，可以稍微调大一点。

#### 常见问题解决和注意事项

- 不出丝：
  - 检查打印平台和喷头的距离是否太近，太近会导致不出丝。此时可以升起喷头，预热完喷头后，手动设置挤出机看是否可以出丝
  - 若手动设置挤出机仍不能出丝，则不是距离问题。若是远程挤出机，则可能是由于之前断料之后，新加的料与断了的料在进入喷头的时候，没有挨着，挤出机只能挤新料，对旧料无法控制。而新料无法将旧料挤出，导致这个问题。此时可以将导管这个接头拧下（如下图），同时令挤出机挤出一段料（长度需足够直接将料压进喷头），手动将料压进喷头。近程挤出机可以直接手动新料压进喷头，一般没有这个问题。
    - ![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/guangzi.jpg
  - 若以上仍没解决，则可能是堵头。此时在机器中手动将喷头预热至最高温度（230-250），同时控制挤出机挤出，看看能否将其挤出。有时候这样可以挤出，但很多时候堵头并不是在喷头处堵住，而是在喷头入口处堵住，导致加热喷头并不能将堵住的料融化。
  - 如果不能，可以考虑使用热风枪，手动加热喷头。需要注意，此操作比较危险，容易将其他线缆烧坏。建议直接将喷头拆下，看看具体是哪里堵住，直接将其剪断即可。
- 首层与平台不粘
  - 平台与喷头距离太远，调整距离为一张A4纸+稍有摩擦的距离
- 翘边
  - 多涂胶，适当压低平台
  - 给打印机加热床（比较麻烦）
  - 打印大件的时候，可以在还未翘边的时候，手动给四角点上热熔胶。（需看准打印机路径，谨慎、快速操作）
- 打出来的圆不圆，或者误差较大
  - 一般是某个轴的同步带松了，调整张紧
- 由于热胀冷缩，打印机喷头预热的时候，会少量吐丝，此时应该用镊子将其清理掉，以防开始打印的时候影响模型造成粘连
- PLA材料不能受力别着，长时间别着（大概几个小时），会变脆，可能会在打印过程中断裂。因此购买材料的时候要把材料理顺。
- PLA材料推荐淘宝店：墨丝、兰博、易生（较贵），PLA加热温度185-200℃，最好首层高温慢打，其他层温度可以稍微调低。这些都可以在cura中设置。
- 步进电机脉冲数计算：
  - 同步轮GT2 20齿 步进电机步距角1.8° 步进电机驱动16细分
  - 可知步进电机走一圈需要200步，则驱动需要给出200*16=3200个脉冲
  - 同步轮转一圈走20（齿）X 2mm（节距） = 40mm
  - 因此，同步轮走1mm需要的脉冲数为 = 3200脉冲/40mm = 80脉冲/mm