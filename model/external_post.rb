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
  class ExternalPost < Sequel::Model
    require 'hpricot'
    include Ramaze::Helper::Link
    include Ramaze::Helper::Wiki
    is :notnaughty
    
    one_to_many  :external_post_taggings, :class => 'Thoth::ExternalPostTagging'
    many_to_many :tags, :class => 'Thoth::Tag', :join_table => :external_post_taggings,
        :order => :name

    validates do
      presence_of :external_id
      presence_of :section_id
      presence_of :url
      presence_of :title
    end

    before_create do
      if self[:locally_created_at].blank? 
        self[:locally_created_at] = Time.now
      end
    end

    before_save do
      self.locally_updated_at = Time.now
    end
    

    # Gets an Array of tags attached to this post, ordered by name.
    def tags
      if new?
        @fake_tags || []
      else
        @tags ||= tags_dataset.all
      end
    end

    def tags=(tag_names)
      if tag_names.is_a?(String)
        tag_names = tag_names.split(',', 64)
      elsif !tag_names.is_a?(Array)
        raise ArgumentError, "Expected String or Array, got #{tag_names.class}"
      end

      tag_names = tag_names.map{|n| n.strip.downcase}.uniq.delete_if{|n|
          n.empty?}

      if new?
        # This Post hasn't been saved yet, so instead of attaching actual tags
        # to it, we'll create a bunch of fake tags just for the preview. We
        # won't create the real ones until the Post is saved.
        @fake_tags = []

        tag_names.each {|name| @fake_tags << Tag.new(:name => name)}
        @fake_tags.sort! {|a, b| a.name <=> b.name }

        return @fake_tags
      else
        real_tags = []

        # First delete any existing tag mappings for this post.
        ExternalPostTagging.filter(:external_post_id => self.id).delete

        # Create new tags and new mappings.
        tag_names.each do |name|
          tag = Tag.find_or_create(:name => name)
          real_tags << tag
          ExternalPostTagging.create(:external_post_id => self.id, :tag_id => tag.id)
        end

        return real_tags
      end
    end   
    
    def source_name
      if self.source == "guardian"
        "The Guardian"
      elsif self.source == "tumblr"
        if ["link"].include?(self.post_type)
          self.url.gsub("http://","").split("/").first
        else
          "Tumblr"        
        end
      else
        self.source
      end   
    end    
    
    def hpricot_body
      Hpricot(self.body_rendered)
    end
    
    def thumbnail
      image = self.hpricot_body.at("img")
      if image
        image.set_attribute("class", "thumbnail")
        return image.to_html
      else
        return nil
      end
    end
    
    #lede is the first 25 words of text with any images stripped out
    def lede(word_count = 25)
      doc = self.hpricot_body
      #wipe images
      doc.search("img").remove
      paras = doc.search("//p")
      text = ""      
      while paras.size > 0 && text.split(" ").size < word_count
        text += paras.shift.to_html
      end
      if (arr = text.split(" ")).size > word_count
        return arr[0..word_count].join(" ") + " ..."
      else 
        return arr.join(" ")
      end
    end
    
    def truncated
      self.lede(60)
    end
    
    class << self
      #CLASS METHODS
      # Gets the published post with the specified name, where _name_ can be
      # either a name or an id. Does not return drafts.
      def get(id_or_external_id)
        id_or_external_id.is_a?(Numeric) ? Post[:id => id_or_external_id] : Post[:external_id => id_or_external_id]
      end   
      
      # Gets a paginated dataset of recent published posts sorted in reverse order
      # by creation time. Does not return drafts.
      def recent(page = 1, limit = 10)
        reverse_order(:created_at).paginate(page,limit)
      end
      
      def import
        self.import_guardian
        self.import_tumblr
      end
      
      def import_guardian
        self.import_guardian_blog(:tag => "technology/series/techweekly", :tag_with => "audio")
        self.import_guardian_blog(:tag => "technology/series/untangling-the-web-with-aleks-krotoski", :tag_with => "uttw")        
      end
      
      def import_tumblr
        self.import_tumblr_blog("theserendipityengine", :tag_with => "serendipity-engine")
        self.import_tumblr_blog("thatsinteres", :tag_with => "lifestream")     
        self.import_tumblr_blog("untanglingtheweb", :tag_with => "uttw")               
      end
      
      def import_guardian_blog(options={})
        posts = Thoth::Plugin::ThothGuardian.import(options)
        saved = []
        failed = []
posts.each do |post|
          if ep = self.first(:source => "guardian", :external_id => post.id)
            break
          else
            ep = self.new
          end
          ep.external_id = post.id
          ep.url = post.url
          ep.source = "guardian"
          ep.section_id = post.section_id
          ep.created_at = Time.parse(post.publication_date.ctime)
          ep.updated_at = Time.parse(post.publication_date.ctime) 
#          ep.type = post["type"]        
          ep.title = post.title
          if post.attributes[:fields] 
            ep.post_type = "long"
            ep.body_rendered = post.attributes[:fields][:standfirst] || post.attributes[:fields][:trailText]
            ep.byline = post.attributes[:fields][:byline]
          else
            ep.post_type = "short"
          end
          begin
            if ep.save  
              if options[:tag_with] && tag = Tag.first(:name => options[:tag_with])
                ep.add_tag tag
              end              
              saved << ep
            else
              failed << ep
            end
          rescue 
            ldbp "Got error '#{$!}' trying to save #{ep.inspect}" 
          end
        end 
        ldbp "Got #{posts.size} guardian posts for #{options.inspect}.  Saved #{saved.size} of them and failed to save #{failed.size} of them."                   
      end
      
      def import_tumblr_blog(blog_name, options={})
        posts = Thoth::Plugin::ThothTumblr.import(blog_name, options)
        saved = []
        failed = []
        posts.each do |post|
          if ep = self.first(:source => "tumblr", :external_id => post["id"])
            #see if the modified field is older than the one we have
            unless ep.updated_at < Time.parse(post["date_gmt"])
              break
            end
          else
            ep = self.new
          end
          begin
            #set some common fields first
            ep.external_id = post["id"]
            ep.url = post["url_with_slug"]
            ep.source = "tumblr"
            ep.section_id = blog_name
            ep.created_at = Time.parse(post["date_gmt"])
            ep.updated_at = Time.parse(post["date_gmt"])  
            ep.post_type = post["type"]        
            #then do the type specific fields
            case post["type"]
            when "photo"
              ep.title =         "From #{blog_name}"
              ep.body_rendered = post["photo_caption"]
              ep.body_rendered << "<img src=\"#{post["photo_url"].grep(/_250\./).first || post["photo_url"].first}\"/>"
            when "video"
              ep.title =         "From #{blog_name}"
              ep.body_rendered = post["video_player"].grep(/width=\"248\"/).first || post["video_player"].first      
              ep.body_rendered = post["video_caption"] || "" 
            when "quote"
              ep.title =         "From #{blog_name}"
              ep.byline =        post["quote_source"]
              ep.body_rendered = "<p>#{post["quote_text"]}</p>"
            when "link"          
              #for links we want to override the external url to go to the link, not to tumblr
              #do we want to do this for other types?
              ep.url = post["link_url"]
              ep.title =         post["link_text"]
              ep.body_rendered = post["link_description"] || ""          
            when "regular"
              ep.title =         post["regular_title"]
              ep.body_rendered = post["regular_body"] || "" 
            end  
            if ep.save  
              if options[:tag_with] && tag = Tag.first(:name => options[:tag_with])
                ep.add_tag tag
              end                 
              saved << ep
            else
              failed << ep
            end
          rescue 
            ldbp "Got error '#{$!}' trying to save #{ep.inspect}, post = #{post.inspect}" 
            failed << ep
          end
        end 
        ldbp "Got #{posts.size} tumblr posts for #{blog_name.inspect}, #{options.inspect}.  Saved #{saved.size} of them and failed to save #{failed.uniq.size} of them."                 
      end #import_tumblr
      
    end #class methods 
    
  end #class
end #module
