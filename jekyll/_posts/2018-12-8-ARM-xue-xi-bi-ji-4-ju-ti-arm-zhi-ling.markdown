---
layout: post
title: ARM学习笔记4——具体arm指令
date: 2018-12-08 22:50:01 +0800
categories: 技术 硬件 arm
issue_id: 46
---
这里就不把书上所有指令抄下来了，仅记录常见或者重要的。

LDR
- LDR既是伪指令，也是arm指令
- 当他是arm指令的时候，格式为 ` LDR R0,[...]`,...有很多种情况
- 当他是伪指令的时候，格式为` LDR R0,=0xFF0`,此时汇编器会决定使用MOV或者MVN来代替LDR，或者是使用基于PC的LDR指令

    - MOV
    ` LDR R0,=0xFF0`
    汇编为`MOV R0,0xFF0`
    
    - LDR
    ` LDR R0,0xFFF`
    汇编为
    ```LDR R0,[PC,OFFSET_TO_LPOOL]
    LPOOL DCD 0xFFF```
    




