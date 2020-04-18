require 'find'

require 'ruby-pinyin'

require File.expand_path('../issue.rb', __FILE__)

class Article
  attr_reader :tags,:time,:file_name,:title
  def initialize(file_name,title=nil)
    @file_name=file_name
    @tags=self.get_tags
    File.open(@file_name) do |f|
      @text=f.read
    end

    self.update_time # 增加时间信息，如果已有直接返回
    self.update_img_mark
    @time=self.get_time
    if !title 
      @title=File.basename(file_name,".md")
    else
      @title=title
    end
  end

  def to_s
    @file_name
  end

  def get_tags
    tags=[]
    File.open(@file_name,'r') do |file|
      file.each_line do |line|
        if line=~/标签..+?/
          r=/(.+?)\s/
          tags=line.scan(r)
          tags.delete_at(0)
          break
        end
      end
    end
    result=[]
    tags.each do|i|
      result.push i[0]
    end
    result
  end

  def is_diary?
    if @text=~/日记/
      return true
    end
    false
  end

  def get_time

    #File.open(@file_name) do |f|
    #  text=f.read
    #  text=~/ctime:.+?\|([0-9]+?)\n/
    #  $1.to_i
    #end
    @text=~/ctime:.+?\|([0-9]+?)\n/
    $1.to_i
  end

  def update_time
    text=String.new
    File.open(@file_name) do |f|
      text=f.read
      time=File.ctime(f).to_s+"|"+File.ctime(f).to_i.to_s
      if not text=~(/ctime:.+?\n/)   # 没有时间信息
        text.sub!(/\n/,"\nctime:#{time}\n") # 在第二行插入
      else
        return text  # 有时间信息了，直接返回
      end

    end
    File.open(@file_name,"w+") do |f|
      f.write text
    end
    text
  end

  def update_img_mark
    text=''
    File.open(@file_name,"r+") do |f|
      text=f.read
      imgpattern=/\[img:(.+?)\]/
      img_result=text.scan(imgpattern)
      img_result.each_with_index do |img_,index|
        img_file_name=img_[0]
        text.sub!(imgpattern,"![此处输入图片的描述][#{index+1}]

[#{index+1}]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/#{img_file_name}")
      end
      f.rewind
      f.write(text)
    end
  end


  def get_jekyll_content

    issueid=0
    read_issue_file do |issue_data,file|
      if issue_data.has_key?(@title)
        issueid=issue_data[@title]
      else
        issueid=create_issue(@title)
        issue_data[@title]=issueid.to_s
      end
      file.rewind
      file.write(issue_data.to_s)
    end
    newhead=begin
      "---
layout: post
title: #{@title}
date: #{Time.at(@time.to_i)}
categories: #{@tags.join(" ")}
issue_id: #{issueid}
---"
    end
    File.open(@file_name) do |f|
      text=f.read
      text.sub!(/\#.+?ctime:.+?\-\-\-/m,newhead)
      text
    end
  end

  def read_issue_file
    File.open("issue.csv","r+") do |f|
      text=f.read
      if text==""
        text="{}"
      end

      yield  eval(text),f
    end
  end


  def get_jekyll_filename
    t=Time.at(@time.to_i)
    temptitle=@title.sub(/\//,'.')
    temptitle.gsub!(' ','')
    temptitle=PinYin.permlink(temptitle)
    "#{t.year}-#{t.month}-#{t.day}-#{temptitle}.markdown"
  end
end



#a=Article.new("关于2017年电设四旋翼的一些反思和总结.md")
#a.get_tags
#puts a.tags
#puts a.tags.length
#a=Article.new("articles/217.md")

