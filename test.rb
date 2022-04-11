require "wordpress_client"

class Wordpress

    @@client = WordpressClient.new(
        url: "https://blog.huangzzk.info/wp-json/",
        username: "ncer",
        password: "wBEC 6P4u C4NF OcOL Wlee bixn",
      )

    @@tags={}
    @@client.tags(per_page:50).each do |a|
        @@tags[a.name_html]=a.id
    end

    def self.tags
        return @@tags
    end


    def self.client
        return @@client
    end

    def self.addtag(tag_name)
        if @@tags.has_key?(tag_name)
            return @@tags[tag_name]
        else
            data={
                name:tag_name
            }
            id=@@client.create_tag(data).id
            @@tags[tag_name]=id
            return id
        end
    end
end
