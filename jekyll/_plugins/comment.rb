module Jekyll
  class RenderCommentTag < Liquid::Tag

    def initialize(tag_name, filename, tokens)
      super
    end

    def render(context)
      ["aa","bb"]
    end
  end
end

Liquid::Template.register_tag('get_comment', Jekyll::RenderCommentTag)
