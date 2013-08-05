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
  class Post < Sequel::Model
    require 'hpricot'
    include Ramaze::Helper::Link
    include Ramaze::Helper::Wiki
    
    #FOLD = /\s*(<p>)?\s*(<|&lt;)!(--|&#8212;)\s*fold\s*(--|&#8212;)(>|&gt;)\s*(<\/p>)?\s*/
    #has to match for web symbols as well as regular characters, and optional spaces, and optional p tag around the fold
    FOLD = /\s*(?:<p>)?\s*(?:&lt;|<)!(?:&#8212;|--)\s*fold\s*(?:&#8212;|--)(?:&gt;|>)\s*(?:<\/p>)?\s*/
    attr_accessor :main_tag

    is :notnaughty

    one_to_many  :taggings, :class => 'Thoth::Tagging'
    many_to_many :tags, :class => 'Thoth::Tag', :join_table => :taggings,
        :order => :name

    validates do
      presence_of :name, :message => 'Please enter a name for this post.'
      presence_of :title, :message => 'Please enter a title for this post.'
      presence_of :body, :message => "Please enter a body for this post."

      length_of :title, :maximum => 255,
          :message => 'Please enter a title under 255 characters.'
      length_of :name, :maximum => 64,
          :message => 'Please enter a name under 64 characters.'

      format_of :name, :with => /^[0-9a-z_-]+$/i,
          :message => 'Post names may only contain letters, numbers, ' <<
                      'underscores, and dashes.'

      format_of :name, :with => /[a-z_-]/i,
          :message => 'Post names must contain at least one non-numeric ' <<
                      'character.'
    end

    before_create do
      if self[:created_at].blank? 
        self[:created_at] = Time.now
      end
    end

    before_destroy do
      Tagging.filter(:post_id => id).delete
      Comment.filter(:post_id => id).delete
    end

    before_save do
      self.updated_at = Time.now
    end

    #--
    # Class Methods
    #++

    # Gets the published post with the specified name, where _name_ can be
    # either a name or an id. Does not return drafts.
    def self.get(name)
      return Post[:id => name, :is_draft => false] if name.is_a?(Numeric)

      name = name.to_s.downcase
      name =~ /^\d+$/ ? Post[:id => name, :is_draft => false] :
          Post[:name => name, :is_draft => false]
    end

    # Returns true if the specified post name is already taken or is a reserved
    # name.
    def self.name_unique?(name)
      !PostController.methods.include?(name) &&
          !PostController.instance_methods.include?(name) &&
          !Post[:name => name.to_s.downcase]
    end

    # Returns true if the specified post name consists of valid characters and
    # is not too long or too short.
    def self.name_valid?(name)
      !!(name =~ /^[0-9a-z_-]{1,64}$/i) && !(name =~ /^[0-9]+$/)
    end

    # Gets a paginated dataset of recent published posts sorted in reverse order
    # by creation time. Does not return drafts.
    def self.recent(page = 1, limit = 10)
      filter(:is_draft => false).reverse_order(:created_at).paginate(page,
          limit)
    end

    # Gets a paginated dataset of recent draft posts sorted in reverse order
    # by creation time. Does not return published posts.
    def self.recent_drafts(page = 1, limit = 10)
      filter(:is_draft => true).reverse_order(:created_at).paginate(page,
          limit)
    end

    # Returns a valid, unique post name based on the specified title. If the
    # title is empty or cannot be converted into a valid name, an empty string
    # will be returned.
    def self.suggest_name(title)
      index = 1

      # Remove HTML entities and non-alphanumeric characters, replace spaces
      # with hyphens, and truncate the name at 64 characters.
      name = title.to_s.strip.downcase.gsub(/&[^\s;]+;/, '_').
          gsub(/[^\s0-9a-z-]/, '').gsub(/\s+/, '-')[0..63]

      # Strip off any trailing non-alphanumeric characters.
      name.gsub!(/[_-]+$/, '')

      return '' if name.empty?

      # If the name consists solely of numeric characters, add an alpha
      # character to prevent name/id ambiguity.
      name += '_' unless name =~ /[a-z_-]/

      # Ensure that the name doesn't conflict with any methods on the Post
      # controller and that no two posts have the same name.
      until self.name_unique?(name)
        if name[-1] == index
          name[-1] = (index += 1).to_s
        else
          name = name[0..62] if name.size >= 64
          name += (index += 1).to_s
        end
      end

      return name
    end

    #--
    # Instance Methods
    #++

    # Gets the Atom feed URL for this post.
    def atom_url
      Config.site.url.chomp('/') + R(PostController, :atom, name)
    end

    def body=(body)
      self[:body]          = body.strip
      self[:body_rendered] = RedCloth.new(wiki_to_html(body.dup.strip)).to_html
    end
    
    def sticky_tag_id=(tag_id)
      Post.filter("sticky_tag_id = ?", tag_id.to_i).all.each{|tag| tag.update(:sticky_tag_id => nil)}
      self[:sticky_tag_id] = tag_id
    end
    
    def sticky_tag
      Tag[self.sticky_tag_id]
    end

    # Gets a dataset of non-spammy comments attached to this post, ordered by creation time.
    def comments
      @comments ||= Comment.filter("post_id = ? and (reported_as_spam is null or reported_as_spam = ?)", self.id, false).order(:created_at)     
    end
    
    # Gets a dataset of spammy comments attached to this post, ordered by creation time.    
    def spam_comments
      @spam_comments ||= Comment.filter(:post_id => id, :reported_as_spam => true).order(:created_at)
    end    

    # Gets the creation time of this post. If _format_ is provided, the time
    # will be returned as a formatted String. See Time.strftime for details.
    def created_at(format = nil)
      if new?
        (format && self[:created_at]) ? Time.now.strftime(format) : Time.now
      else
        (format && self[:created_at]) ? self[:created_at].strftime(format) : self[:created_at]
      end
    end
    
    def created_at=(time)
      if time.kind_of?(Time)
        self[:created_at] = time
      elsif time.kind_of?(String) && !time.blank?
        begin
          parsed_time = DateTime.strptime(time, "%d/%m/%y")
          old_time = self.created_at || Time.now
          return self[:created_at] = Time.local(parsed_time.year, parsed_time.month, parsed_time.day, old_time.hour, old_time.min, old_time.sec)
        rescue
          return false
        end
      end
    end

    def name=(name)
      self[:name] = name.to_s.strip.downcase unless name.nil?
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
        Tagging.filter(:post_id => id).delete

        # Create new tags and new mappings.
        tag_names.each do |name|
          tag = Tag.find_or_create(:name => name)
          real_tags << tag
          Tagging.create(:post_id => id, :tag_id => tag.id)
        end

        return real_tags
      end
    end
    
    def title=(title)
      title.strip!

      # Set the post's name if it isn't already set.
      if self[:name].nil? || self[:name].empty?
        self[:name] = Post.suggest_name(title)
      end

      self[:title] = title
    end

    # Gets the time this post was last updated. If _format_ is provided, the
    # time will be returned as a formatted String. See Time.strftime for
    # details.
    def updated_at(format = nil)
      if new?
        format ? Time.now.strftime(format) : Time.now
      else
        format ? self[:updated_at].strftime(format) : self[:updated_at]
      end
    end

    # Gets the URL for this post.
    def url
      Config.site.url.chomp('/') + R(PostController, name)
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
    
    #will go over the count - will return the whole paragraph (or whatever) that makes it go over the limit.
    def lede2(word_count = 25)
      doc = self.hpricot_body
      result_html = ""
      children = doc.children
      count = 0
      while children.size > 0 && count < word_count
        child = children.shift
        result_html << child.to_s
        count += child.inner_text.split(/\s+/).size
      end
      result_html
    end 
    
    def lede3(word_count = 25)
      words = self.body_rendered.gsub(/<\s*img.*?>/, "").split()
      if words.length <= word_count
        return words.join(" ")
      else
        return "#{words[0, word_count].join(" ")}..."
      end
    end 
    
    def first_paras(num = 2)
      self.body_rendered.scan(/<p>.*<\/p>/)[0..num-1].collect{|p| p.gsub(/<img.*\/>/, "")}.join
    end     
      
    #if there's a <!-- fold --> return everything up to the fold.  If there isn't, use lede2 to get the start
    def to_fold
      arr = self.body_rendered.split(FOLD)
      if arr.size > 1
        arr.first
      else
        self.lede2
      end
    end 
    
  end

  unless Post.count > 0
    Post.create(
      :title => 'Welcome to your new Thoth blog',
      :body  => %[
        If you're reading this, you've successfully installed Thoth. Congratulations!

        Once you've <a href="txmt://open/?url=file://#{Thoth.trait[:config_file]}">edited the config file</a> to your liking, you can <a href="/admin">login</a> and begin creating blog posts and pages. You can also delete this post to make way for your own glorious words.

        Enjoy!
      ].unindent
    )
  end
end
