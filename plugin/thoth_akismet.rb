require 'akismet' #https://github.com/bigthink/akismet
module Thoth; module Plugin
  # Akismet (comment-spam blocker) plugin for Thoth.
  module ThothAkismet
    AKISMET_API_KEY = '105a79a96596'
    SITE_URL = 'http://alekskrotoski.com'  
    
    class << self
      def new_client
        @akismet_client ||= Akismet::Client.new AKISMET_API_KEY, SITE_URL
      end
      
      #returns true for spam, false for not spam
      def check(request, post)
        ip = request.ip
        options = { 
          :comment_type => Akismet::CommentType::COMMENT,
          :permalink => "#{SITE_URL}/posts/#{post.name}",
          :comment_author => request[:author],
          :comment_author_email => request[:author_email],
          :comment_author_url => request[:author_url],
          :comment_content => request[:body]
        }
        self.new_client.check ip, 'user_agent', options    
      end
    end
  end

end; end
