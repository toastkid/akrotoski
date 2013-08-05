require 'tumblr' #https://github.com/jeffkreeftmeijer/tumblr
module Thoth; module Plugin
  # Guardian api wrapper for Thoth
  module ThothTumblr
#    don't need an API key for GET requests
    
    class << self
      def import(blog_name,options={})
        Tumblr.blog = blog_name
        begin
          Tumblr::Post.all(options) #posts is simply an array of hashes
        rescue
          puts "Failed to get tumblr posts for #{blog_name.inspect}: #{$!}"
        end
      end
    end
  end

end; end
