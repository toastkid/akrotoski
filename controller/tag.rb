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
  class TagController < Ramaze::Controller
    map       '/tag'
    layout    '/layouts/layout'
    view_root File.join(Config.theme.view, 'tag'),
              File.join(VIEW_DIR, 'tag')

    helper      :admin, :cache, :error, :pagination
    deny_layout :atom

    if Config.server.enable_cache
      cache :index, :ttl => 120, :key => lambda { auth_key_valid? }
      cache :atom, :ttl => 120
    end

    def index(name = nil, page = 1)
      ldb "in tag controller"
      if @name = name
        @tag = Tag[:name => @name.strip.downcase] 
      else
        @tag = Tag.root
      end
    
      #get some posts, make sure to not get sticky post if we have one.
      if @tag 

        @ancestors = @tag.self_and_ancestors      
        @main_ancestor = @tag.main_ancestor.name   
#        
#        Ramaze::Log.info "page = #{page.inspect}, @posts.page_count = #{@posts.page_count.inspect}"        
#        if page > @posts.page_count && @posts.page_count > 0
#          page = @posts.page_count
#          @posts = @tag.posts.paginate(page, 10)
#        end

        page = page.to_i
        page = 1 unless page >= 1
#        @posts = @tag.posts.paginate(page,10)
        @sticky = @tag.sticky_post
        @posts = @tag.posts_and_external_posts(:page => page, :non_sticky => true)
#        ldb "@posts.size = #{@posts.size}"
        @page_count = @tag.posts_and_external_posts_page_count
        @record_count = @tag.posts_and_external_posts_count(:non_sticky => true)   
#        ldb "@record_count = #{@record_count}"   
        @title = "Academic, Media, UKTI & Personal &mdash; #{@tag.title} Posts (page #{page} of #{@page_count})"

#        @pager = pager(@posts, Rs(name, '%s'))
        @pager = array_pager(@posts, Rs(name, '%s'), {:page => page, :record_count => @record_count})
#        Ramaze::Log.info "@pager = #{@pager.inspect}"        
        
#        %w(current_page current_page_record_count current_page_record_range  navigation? next_page next_url page_count page_range page_size prev_page prev_url record_count).each do |f| 
#          puts "@pager.#{f} = #{@pager.send(f).inspect}"
#          puts "@array_pager.#{f} = #{@array_pager.send(f).inspect}\n "
#        end
#        puts "@pager.url(2) = #{@pager.url(2).inspect}"
#        puts "@array_pager.url(2) = #{@array_pager.url(2).inspect}"
        
        @feeds = [{
          :href  => @tag.atom_url,
          :title => "#{@tag.title} Posts",
          :type  => 'application/atom+xml'
        }]
      end
    end

    def atom(name = nil)
      tag = Tag[:name => name.strip.downcase] if name
      
      if tag 
        posts   = tag.posts.limit(10)
      else
        tag = Tag.root
        posts   Post.limit(10)
      end    
      
      updated = posts.count > 0 ? posts.first.created_at.xmlschema :
          Time.at(0).xmlschema

      response['Content-Type'] = 'application/atom+xml'

      x = Builder::XmlMarkup.new(:indent => 2)
      x.instruct!

      x.feed(:xmlns => 'http://www.w3.org/2005/Atom') {
        x.id       tag.url
        x.title    "Posts tagged with \"#{tag.name}\" - #{Config.site.name}"
        x.updated  updated
        x.link     :href => tag.url
        x.link     :href => tag.atom_url, :rel => 'self'

        x.author {
          x.name  Config.admin.name
          x.email Config.admin.email
          x.uri   Config.site.url
        }

        posts.all do |post|
          x.entry {
            x.id        post.url
            x.title     post.title
            x.published post.created_at.xmlschema
            x.updated   post.updated_at.xmlschema
            x.link      :href => post.url, :rel => 'alternate'
            x.content   post.body_rendered, :type => 'html'

            post.tags.each do |tag|
              x.category :term => tag.name, :label => tag.name,
                  :scheme => tag.url
            end
          }
        end
      }
    end
  end
end
