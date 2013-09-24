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

require 'twitter'
require 'monkeypatch/gems/twitter'

module Thoth; module Plugin

  # Twitter plugin for Thoth.
  module TwitterClient

    Configuration.for("thoth_#{Thoth.trait[:mode]}") do
      twitter {
        consumer_key        Thoth::Config.admin.twitter_consumer_key
        consumer_secret     Thoth::Config.admin.twitter_consumer_secret
        access_token        Thoth::Config.admin.twitter_access_token
        access_token_secret Thoth::Config.admin.twitter_access_token_secret      
        
        # Whether or not to include replies. If this is false, the most recent
        # non-reply tweets will be displayed.
        exclude_replies false

        # Time in seconds to cache results. It's a good idea to keep this nice
        # and high both to improve the performance of your site and to avoid
        # pounding on Twitter's servers. Default is 600 seconds (10 minutes).
        cache_ttl 600 unless Send('respond_to?', :cache_ttl)

        # Request timeout in seconds.
        request_timeout 3 unless Send('respond_to?', :request_timeout)

        # If Twitter fails to respond at least this many times in a row, no new
        # requests will be sent until the failure_timeout expires in order to
        # avoid hindering your blog's performance.
        failure_threshold 3 unless Send('respond_to?', :failure_threshold)

        # After the failure_threshold is reached, the plugin will wait this many
        # seconds before trying again. Default is 600 seconds (10 minutes).
        failure_timeout 600 unless Send('respond_to?', :failure_timeout)        
      }
    end

    class << self
      def client
        if @client 
          return @client
        else
          @client = Twitter.configure do |config|
            config.consumer_key       = Config.twitter.consumer_key
            config.consumer_secret    = Config.twitter.consumer_secret
            config.oauth_token        = Config.twitter.access_token
            config.oauth_token_secret = Config.twitter.access_token_secret
          end  
          return @client
        end
      end
      
      

      # Parses tweet text and converts it into HTML. Explicit URLs and @username
      # or #hashtag references will be turned into links.
      def parse_tweet(tweet)
        index     = 0
        html      = tweet.dup
        protocols = ['ftp', 'ftps', 'git', 'http', 'https', 'mailto', 'scp',
                     'sftp', 'ssh', 'telnet']
        urls      = []

        # Extract URLs and replace them with placeholders for later.
        URI.extract(html.dup, protocols) do |url|
          html.sub!(url, "__URL#{index}__")
          urls << url
          index += 1
        end

        # Replace URL placeholders with links.
        urls.each_with_index do |url, index|
          html.sub!("__URL#{index}__", "<a href=\"#{url}\">" <<
              "#{url.length > 26 ? url[0..26] + '...' : url}</a>")
        end

        # Turn @username into a link to the specified user's Twitter profile.
        html.gsub!(/@([a-zA-Z0-9_]{1,16})([^a-zA-Z0-9_])?/,
            '@<a href="http://twitter.com/\1">\1</a>\2')

        # Turn #hashtags into links.
        html.gsub!(/#([a-zA-Z0-9_]{1,32})([^a-zA-Z0-9_])?/,
            '<a href="http://search.twitter.com/search?q=%23\1">#\1</a>\2')

        return html
      end

      #NEW VERSION USING Twitter API v1.1
      # Gets a Hash containing recent tweets for the specified _user_. The only
      # valid option currently is <code>:count</code>, which specifies the
      # maximum number of tweets that should be returned.
      def recent_tweets(user, options = {})
        defaults = {
          :count => 10,
          :exclude_replies => Config.twitter.exclude_replies
        }
        options = defaults.merge(options)
        #limit options[:count]
        options[:count] = 100 if options[:count] > 100   
        cache_key =   
      
        if @skip_until
          return [] if @skip_until > Time.now
          @skip_until = nil
        end
        
        tweets = self.client.user_timeline(user, options)

        # Parse the tweets into an easier-to-use format.
        tweets.map! do |tweet|
          {
            :created_at => tweet[:created_at],
            :html       => parse_tweet(tweet[:text]),
            :id         => tweet[:id],
            :source     => tweet[:source],
            :text       => tweet[:text],
            :truncated  => tweet[:truncated],
            :url        => "http://twitter.com/#{user}/statuses/#{tweet[:id]}"
          }
        end

        @failures = 0
        
        return Ramaze::Cache.value_cache.store(options.to_s, tweets, :ttl => Config.twitter.cache_ttl)

      rescue => e
        @failures ||= 0
        @failures += 1
      
        if @failures >= Config.twitter.failure_threshold
          @skip_until = Time.now + Config.twitter.failure_timeout
          Ramaze::Log.error("Twitter failed to respond #{@failures} times. " <<
              "Will retry after #{@skip_until}.")
        end
      
        return []
      end

    end

  end
end; end
