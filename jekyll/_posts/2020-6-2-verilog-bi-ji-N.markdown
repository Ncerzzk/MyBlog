---
layout: post
title: verilog 笔记 N
date: 2020-06-02 20:36:50 +0800
categories: 技术 硬件
issue_id: 116
---

- 数组的选择下标，可以为变量 arr[index] index可以为变量
  - 数组的切片arr[5:3],第二个切片不能为变量
    - 但可以使用+: 和 -:运算符
    - 如arr[5 +:4 ] 相当于arr[8:5]
- 异步复位的缺点：
  - 释放的时候，寄存器容易出现亚稳态（当释放的时机靠近时钟的有效沿之时）
  - 容易受毛刺影响
- FPGA中的触发器没有边沿触发器
- 如果赋值时，左右位数不等，右端位宽大则截位 位宽少则补0
- 关于for:
  ```verilog
      always @ (*) begin
        for(int i=0;i<=4;i++) begin
            if(state[i]) begin
                if(in) begin
                    next_state[i+1]=1'b1;
                    next_state[i]=1'b0;
                end
                else begin
                    next_state[i]=1'b0;
                    next_state[0]=1'b1;
                end
            end
        end
    end
  ```
  以上代码本来是想实现一个独热码的状态机比较，但实际上综合完后会出现bug，即，由于只有state[i]的部分，因此
  