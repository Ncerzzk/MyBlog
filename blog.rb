require 'net/http'
require 'open-uri'
require 'find'
require 'pathname'
require File.expand_path('../article.rb', __FILE__)
Encoding.default_external = Encoding.find('utf-8')

ARTICLE_DIR="articles"
class Blog
  def initialize(url)
    @url=url
    @tag_url='tag.md'
    @content_url='README.md'
    @article_path=Pathname.new(File.dirname(__FILE__)).realpath+ARTICLE_DIR
  end

  def self.get_article_title(file_name)
    File.open(file_name,"r") do |f|
      text=f.read()
      text=~/#\s*(.+)/
      return $1
    end
  end

  def get_articles
    a=[]
    Find.find(@article_path) do |filename|
      if filename=~/.+?md/
        basename=File.basename(filename)
        if basename !="README.md" and basename !="tags.md"
          title=Blog.get_article_title(ARTICLE_DIR+"/"+basename)
          a.push Article.new(ARTICLE_DIR+"/"+basename,title)
        end
        #a.push Article.new(File.basename(filename)) if File.basename(filename)  !="README.md" and File.basename(filename)  !="tags.md"
      end
      a.sort_by! do |item|
        item.time
      end
    end
    a
  end



  def update_tag(articles)   # 更新标签
    tags_hash=Hash.new
    articles.each do|article|
      i=0
      article.tags.each do |tag|
        if not tags_hash.has_key? tag
          tags_hash[tag]=Array.new
        end
        tags_hash[tag].push article
      end
    end
    result="## 标签归档\r\n"
    tags_hash.each_key do |key|
      result+="### #{key}\r\n"
      tags_hash[key].each do |article|
        uri="#{@url}/#{article.file_name}"
        result+="[#{article.title}](#{uri})\r\n"
      end
    end
    File.open("tags.md","w+") do |f|
      f.write result
    end
    p result
  end


  def update_content(articles)   # 更新目录
    st="## Content\n"
    text=""
   articles.each do |article|
     uri="(#{@url}/#{article.file_name})"
     #title=File.basename(article.file_name,".md")
     title=article.title
     st=st+"[#{title}]"+uri+"\n\n"
   end
    File.open("README.md","r") do|file|
      text=file.read()
      r=Regexp.new(/## Content.*\z/m)
      range=text=~r..text.length
      text.slice!(range)       #将Range范围内的文本删除
      #file.rewind            #将指针重新回到文件头
      text=text.encode("utf-8")+st.encode("utf-8")
    end
    File.open("README.md","w+")do |file|
      file.write(text)
    end
  end



  def get_time(file_name)
    File.open(file_name) do |f|
      text=f.read
      text=~/ctime:.+?\|([0-9]+?)\n/
      $1.to_i
    end
  end
end


