require 'net/http'
require 'open-uri'
require 'find'
require 'pathname'

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
      end
      a.sort_by! do |item|
        File.ctime(item)
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

  def update_content(articles)
    st="## Content\n"
    text=""
   articles.each do |article|
     uri="(#{@url}/#{article})"
     title=File.basename(article,".md")
     st=st+"[#{title}]"+uri+"\n\n"
   end
    File.open("README.md","r") do|file|
      text=file.read()
      r=Regexp.new(/## Content.*\z/m)
      range=text=~r..text.length
      text.slice!(range)       #将Range范围内的文本删除
      #file.rewind            #将指针重新回到文件头
      text=text+st
    end
    File.open("README.md","w+")do |file|
      file.write(text)
    end
  end
  def update
    update_tag
  end

end

a=Blog.new('https://github.com/Ncerzzk/MyBlog/blob/master')
as=a.get_articles
puts as
a.update_content(as)
