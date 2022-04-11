require 'find'
require "wordpress_client"
require "json"
require "date"
require 'kramdown'


require File.expand_path('../test.rb', __FILE__)
class Article
  attr_reader :tags,:time,:file_name,:title, :content

  def initialize(file_name,title=nil)
    @file_name=file_name
    @tags=self.get_tags
    File.open(@file_name) do |f|
      @text=f.read
    end

    @text=self.update_time # 增加时间信息，如果已有直接返回
    self.update_img_mark
    @time=self.get_time
    @content=self.get_content
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
    #ctime:2017-08-16 23:37:54 +0800|1502897874
    @text=~/ctime:.+?\|([0-9]+)/
    $1.to_i
  end

  def get_content
    @text=~/---(.+)/m
    $1
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
      oldimgpattern = /\!\[.+?\]\[(\d+)\]/
      oldimgresult = text.scan(oldimgpattern)
      start = $1.to_i | 0
      imgpattern=/\[img:(.+?)\]/
      img_result=text.scan(imgpattern)
      img_result.each_with_index do |img_,index|
        img_file_name=img_[0]
        text.sub!(imgpattern,"![此处输入图片的描述][#{start+index+1}]

[#{start+index+1}]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/#{img_file_name}")
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

  def read_WP_file
    File.open("wordpress.csv","r+") do |f|
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

  def create_wp_posts
    tag_ids=[]
    @tags.each do |i|
      if !i.strip.empty?
        tag_ids.push Wordpress.addtag(i.strip)
      end
    end

    data = {
      title: @title,
      status: 'draft', 
      content: @content, #Kramdown::Document.new(@content).to_html,
      date:Time.at(@time).to_datetime.to_s,
      tags:tag_ids.join(',')
    }

    p "create wp posts:#{@title} with tags #{@tags}"

    read_WP_file do |posts_data,file|
      if posts_data.has_key?(@time)
        id=posts_data[@time]
        data[:id]=id
        p "the article #{@title} exist!"
        # Wordpress.client.update_post(id,data)
      else
        id=Wordpress.client.create_post(data).id
        posts_data[@time]=id
        file.rewind
        file.write(posts_data.to_s) 
      end
    end
  end
end


=begin
a=Article.new("articles/ArduPilot中串口的复用.md")
#YYYY-MM-DDTHH:MM:SS
p Time.at(a.time)
p a.tags
p a.time
a.create_wp_posts
=end

#a.get_tags
#puts a.tags
#puts a.tags.length
#a=Article.new("articles/217.md")
