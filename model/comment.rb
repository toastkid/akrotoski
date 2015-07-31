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

require 'digest/md5'
require 'strscan'

module Thoth
  class Comment < Sequel::Model
    include Ramaze::Helper::Link
    
    URL_REGEX = /^(?:$|https?:\/\/\S+\.\S+)/i

    CONFIG_SANITIZE = {
      :elements => [
        'a', 'b', 'blockquote', 'br', 'code', 'dd', 'dl', 'dt', 'em', 'i',
        'li', 'ol', 'p', 'pre', 'small', 'strike', 'strong', 'sub', 'sup',
        'u', 'ul'
      ],

      :attributes => {
        'a'   => ['href', 'title'],
        'pre' => ['class']
      },

      :add_attributes => {'a' => {'rel' => 'nofollow'}},
      :protocols => {'a' => {'href' => ['ftp', 'http', 'https', 'mailto']}}
    }

    is :notnaughty

    validates do
      presence_of :author,       :message => 'Please enter your name.'
#      presence_of :title,        :message => 'Please enter a title for this comment.'

      length_of :author,       :maximum => 64,    :message => 'Please enter a name under 64 characters.'
      length_of :author_email, :maximum => 255,   :message => 'Please enter a shorter email address.'
      length_of :author_url,   :maximum => 255,   :message => 'Please enter a shorter URL.'
      presence_of :body,        :message => 'Please enter some text for this comment.'      
      length_of :body,         :maximum => 65536, :message => 'You appear to be writing a novel. Please try to keep it under 64K.'
#      length_of :title,        :maximum => 100,   :message => 'Please enter a title shorter than 100 characters.'

      format_of :author_email, :with => :email, :message => 'Please enter a valid email address.'
      format_of :author_url,   :with => URL_REGEX, :message => 'Please enter a valid URL or leave the URL field blank.'
    end

    before_create do
      self.created_at = Time.now
    end

    before_save do
      self.updated_at = Time.now
    end

    #--
    # Class Methods
    #++

    # Recently-posted comments (up to _limit_) sorted in reverse order by
    # creation time.
    def self.recent(page = 1, limit = 10)
      self.filter("reported_as_spam is null or reported_as_spam = ?", false).reverse_order(:created_at).paginate(page, limit)
    end
    
    #returns true for spam, false for not spam    
    def is_spam?
      #if we've got another comment marked as spam from this ip address, then spam it instantly
      if Comment.filter(["ip = ? and reported_as_spam = ?", self.ip, true]).first
        self.reported_as_spam = true
        return true
      else
        old = self.reported_as_spam          
        self.reported_as_spam = Thoth::Plugin::ThothAkismet.new_client.check self.ip || "", 'user_agent', self.akismet_options   
        if self.reported_as_spam != old || !self.spam_checked
          self.spam_checked = true
          self.save if self.id #only save the comment if it's already been saved
        end
        return self.reported_as_spam
      end
    end    
    
    def report_spam
      ldb "Marking comment #{self.id} as spam"        
      Thoth::Plugin::ThothAkismet.new_client.spam self.ip || "", 'user_agent', self.akismet_options 
      ldb "Done akismet spam call"                
      unless self.reported_as_spam == true
        ldb "Updating record"        
        self.spam_checked = true      
        self.reported_as_spam = true        
        self.save
      end
    end     
    
    def report_ham
      ldb "Marking comment #{self.id} as ham"            
      Thoth::Plugin::ThothAkismet.new_client.ham self.ip || "", 'user_agent', self.akismet_options 
      unless self.reported_as_spam == false  
        self.spam_checked = true          
        self.reported_as_spam = false
        self.save            
      end
    end
    
    def akismet_options
      { 
        :blog =>                 "http://alekskrotoski.com",  
        :referrer =>             self.referrer || "",             
        :comment_type =>         Akismet::CommentType::COMMENT,
        :permalink =>            "http://alekskrotoski.com/posts/#{self.post.name}",
        :comment_author =>       self.author,
        :comment_author_email => self.author_email,
        :comment_author_url =>   self.author_url,
        :comment_content =>      self.body
      }    
    end
    
    def destroy_if_spam
      begin
        if self.is_spam?
          ldb "comment #{self.id} is spammy"
          self.destroy
          result = true
        else
          ldb "comment #{self.id} is spam-free"            
          self.spam_checked = true
          self.save
          result = false
        end   
      rescue
        #blew up testing if it was spam, probably because we're offline.  Don't do anything with it.
        return nil
      else
        return result
      end     
    end
    
    def self.destroy_if_spam
      spam_count = 0
      not_spam_count = 0
      unknown_count = 0
      comments = Comment.all.reject(&:spam_checked)
      comments.each do |comment|
        result = comment.destroy_if_spam
        if result == true
          spam_count += 1
        elsif result == false
          not_spam_count += 1
        else
          unknown_count += 1
        end
      end;false
      return "Deleted #{spam_count} comments and recorded #{not_spam_count} comments as spam_checked.  Failed to test #{unknown_count} comments."
    end
    
    def self.spam_test_unchecked
      comments = Comment.filter(:spam_checked => nil).all
      self.spam_test_comments(comments)
    end
    
    def self.spam_test_comments(comments)
      comments.each do |comment|
        ldb "Testing comment #{comment.id}"        
        result = comment.is_spam?
        ldb "result is #{result.inspect}"        
      end
      ldb "Tested #{comments.size} comments, marked #{comments.select(&:reported_as_spam).size} as spammy and #{comments.reject(&:reported_as_spam).size} as not spammy"   
      comments 
    end
    
    def self.ip_is_spammy?(ip)
      !!Comment.filter("ip = ? and reported_as_spam = ?", ip, true).first
    end
    
    def similar_comments(*fields)
      ldb "About to test comments for spam which match #{fields.inspect}"        
      unless fields.blank?
        options = {}
        fields.each do |field|
          options[field] = self.send(field)
        end
        ldb "options = #{options.inspect}"                
        comments = Comment.filter(options).filter("id <> ?", self.id).all
        ldb "Got #{comments.size} comments with ids #{comments.collect(&:id).inspect}"
        comments                
      end
    end

    #--
    # Instance Methods
    #++

    def author=(author)
      self[:author] = author.strip unless author.nil?
    end

    def author_email=(email)
      @gravatar_url = nil
      self[:author_email] = email.strip unless email.nil?
    end
    
    def author_url=(url)
      unless url.nil? || url == ""
        url.strip!
        if url !~ /^http:\/\//
          url = "http://"+url
        end
      end   
      self[:author_url] = url 
    end

    def body=(body)
      redcloth = RedCloth.new(body, [:filter_styles])

      self[:body]          = body
      
      if self[:title].nil? || self[:title].empty?
        self[:title] = body[0..25]
      end
      
      self[:body_rendered] = insert_breaks(Sanitize.clean(redcloth.to_html(
        :refs_textile,
        :block_textile_lists,
        :inline_textile_link,
        :inline_textile_code,
        :glyphs_textile,
        :inline_textile_span
      ), CONFIG_SANITIZE))
    end
    
    # Gets the creation time of this comment. If _format_ is provided, the time
    # will be returned as a formatted String. See Time.strftime for details.
    def created_at(format = nil)
      if new?
        format ? Time.now.strftime(format) : Time.now
      else
        format ? self[:created_at].strftime(format) : self[:created_at]
      end
    end

    # Gets the Gravatar URL for this comment.
    def gravatar_url
      return @gravatar_url if @gravatar_url

      md5     = Digest::MD5.hexdigest((author_email || author).to_s.downcase)
      default = CGI.escape(Config.theme.gravatar.default)
      rating  = Config.theme.gravatar.rating
      size    = Config.theme.gravatar.size

      @gravatar_url = "http://www.gravatar.com/avatar/#{md5}.jpg?d=#{default}&r=#{rating}&s=#{size}"
    end

    # Gets the post to which this comment is attached.
    def post
      @post ||= Post[post_id]
    end

    def title=(title)
      self[:title] = title.strip unless title.nil?
    end
    
    # Gets the time this comment was last updated. If _format_ is provided, the
    # time will be returned as a formatted String. See Time.strftime for details.
    def updated_at(format = nil)
      if new?
        format ? Time.now.strftime(format) : Time.now
      else
        format ? self[:updated_at].strftime(format) : self[:updated_at]
      end
    end

    # URL for this comment.
    def url
      new? ? '#' : post.url + "#comment-#{id}"
    end

    protected

    # Inserts <wbr /> tags in long strings without spaces, while being careful
    # not to break HTML tags.
    def insert_breaks(str, length = 30)
      scanner = StringScanner.new(str)

      char    = ''
      count   = 0
      in_tag  = 0
      new_str = ''

      while char = scanner.getch do
        case char
        when '<'
          in_tag += 1

        when '>'
          in_tag -= 1
          in_tag = 0 if in_tag < 0

        when /\s/
          count = 0 if in_tag == 0

        else
          if in_tag == 0
            if count == length
              new_str << '<wbr />'
              count = 0
            end

            count += 1
          end
        end

        new_str << char
      end

      return new_str
    end

  end
end
