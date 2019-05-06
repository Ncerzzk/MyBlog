require 'find'


class Article
  attr_reader :tags,:time,:file_name,:title
  def initialize(file_name)
    @file_name=file_name
    @tags=self.get_tags
    self.update_time # 增加时间信息，如果已有直接返回
    @time=self.get_time
    @title=File.basename(file_name,".md")
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

  def get_time
    File.open(@file_name) do |f|
      text=f.read
      text=~/ctime:.+?\|([0-9]+?)\n/
      $1.to_i
    end
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
end

a=Article.new("关于2017年电设四旋翼的一些反思和总结.md")
a.get_tags
puts a.tags
puts a.tags.length
