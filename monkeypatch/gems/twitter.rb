require 'twitter/base'
module Twitter
  class Identity < Twitter::Base
  
    def initialize(attrs={})
      #HACK: this gem isn't initialising properly from a hash with string keys - convert to symbols
      attrs.each do |k,v|
        if k.is_a?(String)
          attrs[k.to_sym] = v
          attrs.delete(k)
        end
      end      
      super
      raise ArgumentError, "argument must have an :id key" unless id
    end 
  end
end
