require File.expand_path('../blog.rb', __FILE__)
Encoding.default_external = Encoding.find('utf-8')

a=Blog.new('https://github.com/Ncerzzk/MyBlog/blob/master')
as=a.get_articles
for i in as
	a.update_time i
end
puts as
a.update_content(as)