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
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

class PopulateTags < Sequel::Migration

    class Tag < Sequel::Model
    end
    
  def down
    Tag.destroy(:all)
  end

  def up
    
    tagtree =    [
        {:name => "academic", :children => [
          {:name => "publications", :children => []},
          {:name => "presentations", :children => []},
          {:name => "research", :children => [
            {:name => "phd", :children => []},
            {:name => "msc", :children => []}
          ]},
          {:name => "conferences", :children => []}
        ]}, 
        {:name => "media", :children => [
          {:name => "guardian", :children => [
            {:name => "gamesblog", :children => []},
            {:name => "game-theory", :children => []},
            {:name => "tech-weekly", :children => []}
          ]},
          {:name => "bbc", :children => [
            {:name => "digital-revolution", :children => []}
          ]},
          {:name => "public-talks", :children => []}
        ]},     
        {:name => "ukti", :children => [
          {:name => "events", :children => []},
          {:name => "ukti-blog", :children => []}
        ]},
        {:name => "lifestream", :children => [
          {:name => "countryphile", :children => []},
          {:name => "flickr", :children => []}          
        ]}
      ]
    root = Tag.create(:name => "all")
    tagtree.each do |hash|
      tag = Tag.create(:name => hash[:name], :parent_id => root.id)
      hash[:children].each do |childhash|
        child_tag = Tag.create(:name => childhash[:name], :parent_id => tag.id)
        childhash[:children].each do |grandchildhash|
          Tag.create(:name => grandchildhash[:name], :parent_id => child_tag.id)
        end        
      end
    end
  end
end
