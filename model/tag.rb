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

module Thoth
  class Tag < Sequel::Model
    include Ramaze::Helper::Link
  
    is :notnaughty

    one_to_many  :taggings, :class => 'Thoth::Tagging'
    one_to_many  :external_post_taggings, :class => 'Thoth::ExternalPostTagging'    
    many_to_many :posts, :class => 'Thoth::Post',
        :join_table => :taggings, :read_only => true
    many_to_many :external_posts, :class => 'Thoth::ExternalPost',
        :join_table => :external_post_taggings, :read_only => true   

    validates do
      presence_of :name
      length_of :name, :maximum => 64
    end

    def children
      Tag.filter(:parent_id => self.id).order(:position).all
    end    

    def self_and_descendants
      tags = []
      current = [self]
      while current.size > 0
        tags += current
        current = current.collect(&:children).flatten
      end
      tags
    end
    
    def parent
      Tag[:id => self.parent_id]
    end
    
    def ancestors
      arr = []
      tag = self
      until tag.parent_id == nil
        tag = tag.parent
        arr << tag        
      end
      arr.reverse
    end
    
    def self_and_ancestors
      self.ancestors << self
    end
    
    def self_and_non_root_ancestors
      self.self_and_ancestors - [Tag.root]
    end   
    
    def level
      self.ancestors.size
    end
    
    def main_ancestor
      root = Tag.root
      tag = self
      until tag.parent_id == root.id || tag.parent_id.nil?
        tag = tag.parent
      end
      tag
    end
    
    def change_to(other_tag_name)
      other_tag = nil
      if other_tag_name.is_a?(Thoth::Tag)
        other_tag = other_tag_name
      else 
        other_tag = Tag.first(:name => other_tag_name)
      end
      if other_tag
        self.posts.all.each{|p| p.add_tag(other_tag) unless p.tags.include?(other_tag)}
        self.destroy  
        return other_tag
      else
        self.name = other_tag_name
        self.save
        return self
      end
    end
    #########################################
    
    def title
      if self[:title].blank?
        self.name.gsub(/^homepage\:/,"")
      else
        self[:title]
      end
    end
    
    def to_text(style = "barred", level = nil)
      level ||= self.level 
      text = ""
      if level > 0
        case style 
          when "tabbed" 
            text += "#{"\t" * (level - 1 )}" 
          else 
            text += "#{"   |    " * (level - 1)}   |----"
        end
        text += "#{self.name}\n"
      end
      
      self.children.each do |child|
        text += child.to_text(style, level + 1)
      end
      text
    end


    #--
    # Instance Methods
    #++

    # Gets the Atom feed URL for this tag.
    def atom_url
      Config.site.url.chomp('/') + R(TagController, :atom, CGI.escape(name))
    end

    # Gets published posts with this tag OR this tag's descendants
    def posts(options={})
      tags = self.self_and_descendants
      post_ids = Tagging.filter([[:tag_id, tags.collect(&:id)]]).select(:post_id).collect(&:post_id).uniq
      query = Post.filter([[:id, post_ids]]).filter(:is_draft => false).reverse_order(:created_at)
      if options[:non_sticky] && sticky = self.sticky_post
        query = query.filter("posts.id <> ?", sticky.id)
      end      
      if options[:page]     
        query = query.paginate(options[:page], options[:per_page] || 10)
      end
      query
    end
    
    def external_posts(options={})
      ldb "self = #{self.inspect}, options = #{options.inspect}"
      tags = self.self_and_descendants
      ldb "got tags: #{tags.collect{|t| [t.id, t.name]}.inspect}"
      external_post_ids = ExternalPostTagging.filter([[:tag_id, tags.collect(&:id)]]).select(:external_post_id).collect(&:external_post_id).uniq   
      query = ExternalPost.filter([[:id, external_post_ids]]).reverse_order(:created_at) 
      if options[:page] 
        query = query.paginate(options[:page], options[:per_page] || 10)
      end
      query
    end    
    
    def posts_and_external_posts(options={})
      ldb "self = #{self.inspect}, options = #{options.inspect}"    
      options[:per_page] ||= 10
      page = options.delete(:page) #can't paginate till we get all of the results
      all = (self.posts(options).all + self.external_posts(options).all).sort_by(&:created_at).reverse
      if page        
        start_i = 0 + ((page - 1) * (options[:per_page]))
        end_i = start_i + (options[:per_page] - 1)      
        all = all[start_i..end_i]
      end
      all
    end
    
    def posts_and_external_posts_page_count(options={})
      options[:per_page] ||= 10    
      ((self.external_posts.count + self.posts.count).to_f/options[:per_page]).ceil
    end
    
    def posts_and_external_posts_count(options={})
      self.external_posts(options).count + self.posts(options).count
    end    
    
    # Gets unpublished posts with this tag.
    def drafts
      @drafts ||= posts_dataset.filter(:is_draft => true).reverse_order(
          :created_at)
    end    
    
    def sticky_post
      Post.filter(:sticky_tag_id => self.id).order(:updated_at.desc).first
    end
    
    def sticky_post=(post)
      post.update(sticky_tag_id => self.id)
    end
    
    def bio_post
      self.drafts.filter("name like ?", "%bio-text").first
    end
    
    def contact_post
      self.drafts.filter("name like ?", "%contact-text").first
    end
    

    # URL for this tag.
    def url
      Config.site.url.chomp('/') + self.path
    end
    
    def path
      if self.name =~ /homepage\:/
        "/#{CGI.escape(self.name.gsub("homepage:",""))}"
      else
         R(TagController, CGI.escape(self.name))
      end
    end
    
    class << self
      #--
      # Class Methods
      #++
  
      # Gets an array of tag names and post counts for tags with names that begin
      # with the specified query string.
      def suggest(query, limit = 1000)
        tags = []
  
        self.dataset.grep(:name, "#{query}%").all do |tag|
          tags << [tag.name, tag.posts.count]
        end
  
        tags.sort!{|a, b| b[1] <=> a[1]}
        tags[0, limit]
      end
      
      def nav_tags
        Tag.filter("parent_id is not null").all
      end
      
      #--
      #  Tree methods
      #++
      
      def root
        self[:name => "all"]
      end
      
      def level_1
        self.root.children
      end
      
      def level_2
        self.level_1.collect{|tag| tag.children}.flatten
      end 
      
      def level_3
        self.level_2.collect{|tag| tag.children}.flatten
      end       
      
      def popular_tag_ids
        Tag.left_outer_join(:taggings, :tag_id => :id).group(:tag_id).order("count(*) desc").all.collect{|tag| tag[:tag_id]}.reject{|x| x.blank?}
      end
      
      def popular_tags
        tag_ids = self.popular_tag_ids
        tags = (Tag.filter("name like 'homepage:%'").all + Tag.filter("id in (#{tag_ids.join(",")})").order("find_in_set(id, #{tag_ids.join(",")})").all).uniq
      end  
      
      #expects params like {"54"=>{"position"=>"1", "parent_id"=>"23"} where the 54 is the id of a tag
      def update_tags(tag_params)
        tag_params.each do |tag_id, attributes|
          ldb "Calling Tag[#{tag_id.inspect}].update(#{attributes.inspect})"
          Tag[tag_id].update(attributes)
        end
      end  
    end
  end
end
