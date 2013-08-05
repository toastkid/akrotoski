require 'guardian-content' #https://github.com/guardian-openplatform/contentapi-ruby
module Thoth; module Plugin
  # Guardian api wrapper for Thoth
  module ThothGuardian
    GUARDIAN_CONTENT_API_KEY= 'rapg77ymmuwu3nrne8k5bcjs'
    SITE_URL = 'http://alekskrotoski.com'  
    
    class << self
      def import(options={})
        if options[:tag]
          GuardianContent::Content.search("", :limit => 20, :conditions => {:tag => options[:tag]}, :select => {:fields => :all})
        end
      end    
    end
  end

end; end
