#--
# Copyright (c) 2009 Ryan Grove <ryan@wonko.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of this project nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, homepage, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++


class RearrangeTagPositions < Sequel::Migration

  #in most cases, for the navbar, the titleized version of the tag name is fine.  But there's a couple that we need to override
  #and set explicitly, eg BBC, UKTI.
  
  class Tag < Sequel::Model;end
  
  def up
    #main nav
    Tag[312].update(:parent_id => 1, :position => 1)
    Tag[2].update(:parent_id => 1, :position => 2)
    Tag[9].update(:parent_id => 1, :position => 3)
    Tag[182].update(:parent_id => 1, :position => 4)
    Tag[158].update(:parent_id => 1, :position => 5)
    Tag[252].update(:parent_id => 1, :position => 6)
    Tag[20].update(:parent_id => 1, :position => 7)
    Tag[317].update(:parent_id => 1, :position => 8)
    #academic (tag 2)
    Tag[3].update(:position => 1)
    Tag[6].update(:position => 2)
    Tag[7].update(:position => 3)
    #media (tag 9)
    Tag[14].update(:position => 1)
    Tag[10].update(:position => 2)
    Tag[16].update(:position => 3)  
    #guardian (tag 10)  
    Tag[11].update(:position => 1)
    Tag[12].update(:position => 2)
    Tag[13].update(:position => 3)      
  end  
  
  def down
  end

end
