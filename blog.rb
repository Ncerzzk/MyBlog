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
        a.push File.basename(filename)
      end
      a.sort_by! do |item|
        File.mtime(item)
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
   articles.each do |article|
     uri="(#{@url}/#{article})"
     title=File.basename(article,".md")
     st=st+"[#{title}]"+uri+"\n\n"
   end
    file=File.new("README.md","r")
    text=file.read()
    r=Regexp.new(/## Content.*\z/m)
    range=text=~r..text.length
    text.slice!(range)
    file.rewind
    text=text+st
    file.close
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
