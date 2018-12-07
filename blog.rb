require 'net/http'
require 'open-uri'
require 'find'
require 'pathname'
Encoding.default_external = Encoding.find('utf-8')

class Blog
  def initialize(url)
    @url=url
    @tag_url='tag.md'
    @content_url='README.md'
    @path=Pathname.new(File.dirname(__FILE__)).realpath
  end

  def get_articles
    a=[]
    Find.find(@path) do |filename|
      if filename=~/.+?md/
        a.push File.basename(filename) if File.basename(filename)  !="README.md"
        update_time filename
      end
      a.sort_by! do |item|
        get_time item
      end
    end
    a
  end

  def update_tag
    uri="#@url/#@tag_url"
    uri=@url
    uri=URI.parse(uri)
    http=Net::HTTP.new(uri.host,uri.port)
    http.use_ssl =true
    request=Net::HTTP::Get.new(uri)

    result=http.request(request)

    puts result.body

  end


  def update_content(articles)   # 更新目录
    st="## Content\n"
    text=""
   articles.each do |article|
     uri="(#{@url}/#{article})"
     title=File.basename(article,".md")
     st=st+"[#{title}]"+uri+"\n\n"
   end
   File.open("Article.rb","r")
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
  def update
    update_tag
  end

  def update_time(file_name)
    text=String.new
    File.open(file_name) do |f|
      text=f.read
      time=File.ctime(f).to_s+"|"+File.ctime(f).to_i.to_s
			if not text=~(/ctime:.+?\n/)   # 没有时间信息
				text.sub!(/\n/,"\nctime:#{time}\n") # 在第二行插入
      else
        return text  # 有时间信息了，直接返回
			end

    end
    File.open(file_name,"w+") do |f|
      f.write text
    end
    text
  end

  def get_time(file_name)
    File.open(file_name) do |f|
      text=f.read
      text=~/ctime:.+?\|([0-9]+?)\n/
      $1.to_i
    end
  end
end


