require File.expand_path('../blog.rb', __FILE__)
Encoding.default_external = Encoding.find('utf-8')

a=Blog.new('https://github.com/Ncerzzk/MyBlog/blob/master')
as=a.get_articles

as.each do |item|
  p item.file_name
end
a.update_content(as)
a.update_tag as
a.update_to_jekyll as

exec "git add ."
exec "git commit -m 'update'"
exec "git push"
exec "cd ./jekyll"
exec "jekyll build"

