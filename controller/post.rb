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
  class PostController < Ramaze::Controller
    map       '/post'
    layout    '/layouts/layout'
    view_root File.join(Config.theme.view, 'post'),
              File.join(VIEW_DIR, 'post')

    helper      :admin, :cache, :cookie, :error, :pagination, :wiki
    deny_layout :atom

    if Config.server.enable_cache
      cache :atom, :ttl => 120
    end

    def index(name = nil)
      error_404 unless name && @post = Post.get(name)

      # Permanently redirect id-based URLs to name-based URLs to reduce search
      # result dupes and improve pagerank.
      raw_redirect(@post.url, :status => 301) if name =~ /^\d+$/

      if request.post? && Config.site.enable_comments
        # Dump the request if the robot traps were triggered.
        #NOTE: in a desperate attempt to beat the spambots, request['captcha'] is now the actual comment body, 
        #and request["body"] is now the honeytrap
        if !request['body'].empty? || Comment.filter(["ip = ? and created_at > ?", request.ip, 5.seconds.ago])
          error_404 
        
        ldb "making a new comment"
        # Create a new comment.
        comment = Comment.new do |c|
          c.post_id      = @post.id
          c.referrer     = request.referrer
          c.author       = request[:author]
          c.author_email = request[:author_email]
          c.author_url   = request[:author_url]
#          c.title        = request[:title]
          c.body         = request[:captcha]
          c.ip           = request.ip
        end
        ldb "comment.id = #{comment.id.inspect}"
        
        
        unless @duplicate = Comment.find({:author => comment.author, :body => comment.body, :post_id => comment.post_id})
          begin 
            @is_spam = comment.is_spam?
            c.spam_checked = true
          rescue
            #blew up while testing if comment is spam, probably because we're offline.
            #leave @is_spam undefined, ie allow comment to be posted, but it will not be marked as having been spam checked so we 
            #can test it later with Comment.delete_spam
          end
        end
        
        if @duplicate
          ldb "Found a duplicate comment, not saving"                  
          @comment_error = "You've already posted this comment on this article, did you hit the button twice?"
          flash[:error] = @comment_error           
        elsif @is_spam
          ldb "akismet reckons comment is spam, not saving"                  
          @comment_error = "Sorry, your comment has been flagged as spam by Akismet"
          flash[:error] = @comment_error
        else
          ldb "not spam or duplicate, saving comment"          

          # Set cookies.
          expire = Time.now + 5184000 # two months from now

          response.set_cookie(:thoth_author, :expires => expire, :path => '/',
              :value => comment.author)
          response.set_cookie(:thoth_author_email, :expires => expire,
              :path => '/', :value => comment.author_email)
          response.set_cookie(:thoth_author_url, :expires => expire, :path => '/',
              :value => comment.author_url)

          if comment.valid? && request[:action] == 'Post Comment'
            begin
              raise unless comment.save
            rescue => e
              @comment_error = 'There was an error posting your comment. ' <<
                  'Please try again later.'
            else
              flash[:success] = 'Comment posted.'
              redirect(Rs(@post.name) + "#comment-#{comment.id}")
            end
          end

          @author       = comment.author
          @author_email = comment.author_email
          @author_url   = comment.author_url
          @preview      = comment
        end
      elsif Config.site.enable_comments
        @author       = cookie(:thoth_author, '')
        @author_email = cookie(:thoth_author_email, '')
        @author_url   = cookie(:thoth_author_url, '')
      end

      @title = @post.title

      if Config.site.enable_comments
        @comment_action = Rs(@post.name) + '#post-comment'

        @feeds = [{
          :href  => @post.atom_url,
          :title => 'Comments on this post',
          :type  => 'application/atom+xml'
        }]
      end

      @show_post_edit = true
    end

    def atom(name = nil)
      error_404 unless name && post = Post.get(name)

      # Permanently redirect id-based URLs to name-based URLs to reduce search
      # result dupes and improve pagerank.
      raw_redirect(post.atom_url, :status => 301) if name =~ /^\d+$/

      comments = post.comments.reverse_order.limit(20)
      updated  = comments.count > 0 ? comments.first.created_at.xmlschema :
          post.created_at.xmlschema

      response['Content-Type'] = 'application/atom+xml'

      x = Builder::XmlMarkup.new(:indent => 2)
      x.instruct!

      x.feed(:xmlns => 'http://www.w3.org/2005/Atom') {
        x.id       post.url
        x.title    "Comments on \"#{post.title}\" - #{Config.site.name}"
        x.updated  updated
        x.link     :href => post.url
        x.link     :href => post.atom_url, :rel => 'self'

        comments.all do |comment|
          x.entry {
            x.id        comment.url
#            x.title     comment.title
            x.published comment.created_at.xmlschema
            x.updated   comment.updated_at.xmlschema
            x.link      :href => comment.url, :rel => 'alternate'
            x.content   comment.body_rendered, :type => 'html'

            x.author {
              x.name comment.author

              if comment.author_url && !comment.author_url.empty?
                x.uri comment.author_url
              end
            }
          }
        end
      }
    end

    def delete(id = nil)
      require_auth

      error_404 unless id && @post = Post[id]

      if request.post?
        error_403 unless form_token_valid?

        if request[:confirm] == 'yes'
          @post.destroy
          action_cache.clear
          flash[:success] = 'Blog post deleted.'
          redirect(R(MainController))
        else
          redirect(@post.url)
        end
      end

      @title          = "Delete Post: #{@post.title}"
      @show_post_edit = true
    end

    def edit(id = nil)
      require_auth

      unless @post = Post[id]
        flash[:error] = 'Invalid post id.'
        redirect(Rs(:new))
      end

      if request.post?
        error_403 unless form_token_valid?

        if request[:name] && !request[:name].empty?
          @post.name = request[:name]
        end

        @post.title = request[:title]
        @post.body  = request[:body]
        @post.tags  = request[:tags]
        @post.sticky_tag_id  = request[:sticky_tag_id]
        
        @post.is_draft = @post.is_draft ? request[:action] != 'Publish' :
            request[:action] == 'Unpublish & Save as Draft'
        
        #set created at automatically or from string if we got it
        request[:created_at] = nil if request[:created_at].blank?
        if @post.is_draft
          @post.created_at = request[:created_at] || Time.now 
        else
          @post.created_at = request[:created_at] if request[:created_at]
        end

        if @post.valid? && (@post.is_draft || request[:action] == 'Publish')
          begin
            Thoth.db.transaction do
              raise unless @post.save && @post.tags = request[:tags]
            end
          rescue => e
            @post_error = "There was an error saving your post: #{e}"
          else
            if @post.is_draft
              flash[:success] = 'Draft saved.'
              redirect(Rs(:edit, @post.id))
            else
              action_cache.clear
              flash[:success] = 'Blog post published.'
              redirect(Rs(@post.name))
            end
          end
        end
      end

      @title          = "Edit blog post - #{@post.title}"
      @form_action    = Rs(:edit, id)
      @show_post_edit = true
    end

    def list(page = 1)
      require_auth

      page = page.to_i

      @columns  = [:id, :title, :sticky_tag_id, :created_at, :updated_at]
      @order    = (request[:order] || :desc).to_sym
      @sort     = (request[:sort]  || :created_at).to_sym
      @sort     = :created_at unless @columns.include?(@sort)
      @sort_url = Rs(:list, page)

      @posts = Post.filter(:is_draft => false).paginate(page, 20).order(
          @order == :desc ? @sort.desc : @sort)

      if page == 1
        @drafts = Post.filter(:is_draft => true).order(
            @order == :desc ? @sort.desc : @sort)
      end

      @title = "Blog Posts (page #{page} of #{[@posts.page_count, 1].max})"
      @pager = pager(@posts, Rs(:list, '%s', :sort => @sort, :order => @order))
    end

    def new
      require_auth

      @title       = "New blog post - Untitled"
      @form_action = Rs(:new)

      if request.post?
        error_403 unless form_token_valid?

        @post = Post.new do |p|
          if request[:name] && !request[:name].empty?
            p.name = request[:name]
          end

          p.title    = request[:title]
          p.body     = request[:body]
          p.tags     = request[:tags]
          p.sticky_tag_id   = request[:sticky_tag_id]          
          p.is_draft = request[:action] == 'Save & Preview'
          
          #set created at automatically or from string if we got it
          p.created_at = request[:created_at] unless request[:created_at].blank?
        end

        if @post.valid?
          begin
            Thoth.db.transaction do
              raise unless @post.save && @post.tags = request[:tags]
            end
          rescue => e
            @post.is_draft = true
            @post_error    = "There was an error saving your post: #{e}"
          else
            if @post.is_draft
              flash[:success] = 'Draft saved.'
              redirect(Rs(:edit, @post.id))
            else
              action_cache.clear
              flash[:success] = 'Blog post published.'
              redirect(Rs(@post.name))
            end
          end
        else
          @post.is_draft = true
        end
        @title = "New blog post - #{@post.title}"
      end
    end
  end
end
