module Thoth
  module Plugin
    module GeneralHelpers
      
      def self.subtags
   
      end

      def self.navbar_li(tag, options = {})
        html = "<li>"
        html += "<a href='/#{tag.self_and_non_root_ancestors.collect{|t| t.name}.join("/")}' class='#{ 'active' if options[:current]}'>#{tag.name}</a>"
        html += "</li>"
        return html
      end
    end
  end

end

##define helper methods here
#module Ramaze; module Helper; module General
##  
##  def say(something)
##    something.inspect
##  end

#end; end; end



#module Thoth
##add general helpers into normal controller helpers
#  class Maincontroller < Ramaze::Controller
#  
#    helper      :admin, :cache, :error, :pagination
#  end
#
#  class TagController < Ramaze::Controller
#    helper      :admin, :cache, :error, :pagination, :general
#  end
#end
#  

