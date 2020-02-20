---
layout: post
title: Git 将git仓库下的某个文件分离为子模块单独开发
date: 2020-01-26 23:48:47 +0900
categories: 技术
issue_id: 0
--- 
记录一下：
- 
```
git subtree split -P <name-of-folder> -b <name-of-new-branch> 
```
  - name-of-folder 目录名
  - name-of-new-branch 新子模块名
---

- 创建一个新的repo
```
git init
git pull </path/to/big-repo> <name-of-new-branch>
```
- 推到github的一个新仓库下
---
- 删除原来的cache
```
git rm -r --cached <name-of-folder>
```
---
- 添加子模块
```
git submodule add <git@github.com:my-user/new-repo.git <name-of-folder>
```



