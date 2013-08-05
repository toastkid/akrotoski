module Thoth
  module CustomLog
    def ldb(debug_text)
      Ramaze::Log.debug "### #{caller[0].gsub("#{Thoth::HOME_DIR}",".")}: #{debug_text}"
    end
    
    def ldbp(debug_text)
      puts debug_text
      Ramaze::Log.debug "### #{caller[0].gsub("#{Thoth::HOME_DIR}",".")}: #{debug_text}"
    end
  end
end

module Ramaze
  class Controller
    include Thoth::CustomLog
  end
  
  module Helper
    include Thoth::CustomLog
  end
end

module Sequel
  class Model
    class << self
      include Thoth::CustomLog
    end
    include Thoth::CustomLog
  end
end
