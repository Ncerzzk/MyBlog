require 'find'

class Article
  attr_reader :tags
  def initialize(file_name)
    @file_name=file_name
    @tags=Array.new()
  end
  def get_tags
    File.open(@file_name,'r') do |file|
      file.each_line do |line|
        if line=~/标签..+?/
          r=/(.+?)\s/
          @tags=line.scan(r)
          @tags.delete_at(0)
          break
        end
      end
    end
  end

end

a=Article.new("关于2017年电设四旋翼的一些反思和总结.md")
a.read_from_file
puts a.tags
puts a.tags.length
