
require "pathname"
require File.expand_path('../blog.rb', __FILE__)
Encoding.default_external = Encoding.find('utf-8')

a=Blog.new('https://github.com/Ncerzzk/MyBlog/blob/master')



for i in a.get_articles()
  file_path=File.expand_path('../'+i,__FILE__)
  a.update_time file_path

  a.get_time file_path
  print "\r\n"

end



