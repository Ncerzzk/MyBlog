---
layout: post
title: RPG_maker_XP中脚本执行流程分析
date: 2017-10-25 10:18:37 +0800
categories: ruby 技术
issue_id: 18
---
从小到大，一直想好好学一下rpg maker，这几天总算有点时间，于是就下了个RMXP来看看。

因为之前好好学了一下ruby的语法，因此现在看这些脚本，终于没有以前看天书的感觉了，也能感受到其中的逻辑了。

这里分析一下默认脚本中的执行流程。了解清楚整个执行流程对不管是要自己写一个新系统还是沿用老系统进行修改定制都是很有必要的。

一开始执行的是Main脚本，主要是设置字体等，真正有用的是这句话
```ruby
    $scene = Scene_Title.new
    while $scene != nil
        $scene.main
    end
```

此时切换到了Scene_Title脚本中，运行main方法

在Scene_Title的main中，
```ruby
    #载入数据文件：
    $data_actors = load_data("Data/Actors.rxdata")
    #生成系统对象：
    $game_system = Game_System.new
    #生成标题图形
    @sprite = Sprite.new
    @sprite.bitmap = RPG::Cache.title($data_system.title_name)
```
Sprite是一个精灵类，和图片显示有关的都在其中进行定义
RPG::Cache是RGSS内部模块，这里用来读取标题图片文件，返回的是一个bitmap对象
接下来：
```ruby
    s1 = "新游戏"
    s2 = "继续"
    s3 = "退出"
    @command_window = Window_Command.new(192, [s1, s2, s3])
```
生成命令选择窗口，调用了`Window_Command`这个类，这个类是`Window_Selectable`的子类
接着设置这个窗口的透明度，显示位置（坐标）等，同时对存档进行校验，如果存在存档，那么Load这个按钮就不显示为灰色
之后就进入了循环
```ruby
    Graphics.transition
    # 主循环
    loop do
      # 刷新游戏画面
      Graphics.update
      # 刷新输入信息
      Input.update
      # 刷新画面
      update
      # 如果画面被切换就中断循环
      if $scene != self
        break
      end
    end
```
`Graphics.update`这个方法，用来刷新游戏画面，必须每帧调用一次，否则10秒未调用的话，RGSS将判断哪里出现了问题，会强行结束程序。

接着刷新输入信息，最后调用`update`方法，这个到底用来刷新啥呢？
其定义为：
```ruby
 def update
    # 刷新命令窗口
    @command_window.update
    # 按下 C 键的情况下
    if Input.trigger?(Input::C)
      # 命令窗口的光标位置的分支
      case @command_window.index
      when 0  # 新游戏
        command_new_game
      when 1  # 继续
        command_continue
      when 2  # 退出
        command_shutdown
      end
    end
  end
```
也就是实际上`update`是在刷新命令选择窗口，`command_window.update`实际上也没刷新什么东西，就是判断一下当前的窗口皮肤是不是换了，如果换了赶紧把皮肤缓存给改了。这个是继承自`Window_Base`的。

那么，如果此时用户按下了 新游戏 的按钮，
程序继续走：
```ruby
    # 主要就是生成各种对象 $game_temp、$game_system 等
    $game_temp= Game_Temp.new
    ...
    # 设置初期同伴位置
    $game_party.setup_starting_members
    # 设置初期位置的地图
    $game_map.setup($data_system.start_map_id)
    # 主角向初期位置移动
    $game_player.moveto($data_system.start_x, $data_system.start_y)
    # 刷新主角
    $game_player.refresh
    # 执行地图设置的 BGM 与 BGS 的自动切换
    $game_map.autoplay
    # 刷新地图 (执行并行事件)
    $game_map.update
    # 切换地图画面
    $scene = Scene_Map.new    
```
这一部分注释写的够清楚了，主要就是开始游戏前的准备，设置好初期的队伍，把主角放到设置好的起点上，然后切换到该地图。

可以看到，这个时候已经修改全局变量`$scene`了，而前面有一句：
```ruby
      if $scene != self
        break
      end
```
因此，跳出了前面的循环，接下来将该释放的东西释放掉：
```ruby
    @command_window.dispose
    # 释放标题图形
    @sprite.bitmap.dispose
    @sprite.dispose
```
释放完毕后，返回Main中，继续:
```ruby
  while $scene != nil
    $scene.main
  end
```
因为此时`$scene`指向的是`Scene_Map`的实例，所以此时调用的是`Scene_Map.main`

`Scene_Map.main`中与`Scene_Title`差别不大，区别在于，Map中有这么一句：
```@spriteset = Spriteset_Map.new```
生成了一个地图精灵的实例，地图上所有显示的精灵，如主角、事件、天气等，都在这个类中进行定义

我们现在去看看这个类的构造函数
```ruby
    @viewport1 = Viewport.new(0, 0, 640, 480)
    @viewport2 = Viewport.new(0, 0, 640, 480)
    @viewport3 = Viewport.new(0, 0, 640, 480)
    @viewport2.z = 200
    @viewport3.z = 5000
```
先是实例化了三个ViewPort，关于这个类的详细说明去看F11，简要的说就是这个类能部分显示一张图片。如行走图，每次我们只需要其中的1/16，因此就需要用这个类来处理。
这里为什么实例化了三个呢？因为有三个图层嘛。

之后是地图元件的处理，这里略去不讲。
```ruby
    @character_sprites = []
    for i in $game_map.events.keys.sort
      sprite = Sprite_Character.new(@viewport1, $game_map.events[i])
      @character_sprites.push(sprite)
    end
    @character_sprites.push(Sprite_Character.new(@viewport1, $game_player))
```
这里就是生成角色、事件的精灵，都放在`@character_sprites`这个数组里。构造函数里剩下的就没什么了。

```@spriteset = Spriteset_Map.new```这句话执行完毕后，同样进入主循环里进行画面的刷新。



