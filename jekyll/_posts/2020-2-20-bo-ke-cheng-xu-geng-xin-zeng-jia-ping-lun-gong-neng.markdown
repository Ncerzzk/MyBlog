---
layout: post
title: 博客程序更新，增加评论功能 
date: 2020-02-20 18:44:00 +0800
categories: 博客
issue_id: 79
---

实际上博客增加了不少功能，赶紧更新一下，不然以后出了问题都忘了是改了那些文件了。

- 在文章中可以使用![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/filename.jpg来上传图片，不然markdown的引用图片语法我是真记不住
  - 在article.rb中会自动把这个标志替换成正常的markdown引用语法，并且图片地址是博客的地址
- 增加评论功能，原理是使用github的issue来保存评论，每篇文章对应一个issue
  - 有一个映射表 issue.csv 来保存已经生成issue的文章，否则总不能每次更新的时候，又把每篇文章再发一个issue吧
  - 用ajax异步加载issue中的comment，然后渲染出来，js好久没写了，写得贼难受
- 使用了jekyll，在原来的article.rb中，增加了update_to_jekyll的函数，用来在每篇文章前面增加YAML信息，这样可以兼容以前文章，而且就算以后不想用jekyll了，也不必修改原来的东西，只需要把update_to_jekyll注释掉
- 写了个shell脚本，功能主要是写完文章后，调用jekyll serve，再进入jekyll的_site，git add .,commit, push，然后再回到博客的根目录，再git add , commit,push 
- 把博客放到服务器上之后，用定时任务10分钟一次调用git pull 来获取文章更新





