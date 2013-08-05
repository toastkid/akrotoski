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

class CreateContactPagePost < Sequel::Migration

  class Post < Sequel::Model
  end

  def down
    if post = Post[:name => "aleks-contact-text"]
      post.destroy
    end
  end

  def up
    html = <<ENDTEXT
	<p class="contactservices"> 
		<a href="http://twitter.com/aleksk" title="See Aleks' Twitter page" class="twitter">Twitter</a> 
		<a href="http://www.facebook.com/alekskrotoski" title="See Aleks' Facebook page" class="facebook">Facebook</a> 
		<a href="http://www.linkedin.com/in/alekskrotoski" title="See Aleks' Linked In page" class="linkedin">Linked In</a> 
	</p> 
        
	<p class="emailinfo"> 
 
<a href="&#109;&#97;&#105;&#108;&#116;&#111;&#58;&#99;&#111;&#110;&#116;&#97;&#99;&#116;&#64;&#97;&#108;&#101;&#107;&#115;&#107;&#114;&#111;&#116;&#111;&#115;&#107;&#105;&#46;&#99;&#111;&#109;" title='ask me questions'>&#99;&#111;&#110;&#116;&#97;&#99;&#116;&#64;&#97;&#108;&#101;&#107;&#115;&#107;&#114;&#111;&#116;&#111;&#115;&#107;&#105;&#46;&#99;&#111;&#109;</a> 
 
 
</p> 
		
	<div class="contactinfo"> 
		<h3>Press &amp; Media Requests:</h3> 
		<p> 
			c/o Rosemary Scoular<br/> 
			<a href="http://www.unitedagents.co.uk">unitedagents.co.uk</a><br/> 
			12-26 Lexington Street,<br/> 
			London, W1F 0LE
		</p> 
		<p><abbr title="telephone number:">t.</abbr> +44 (0)20 3214 0800</p> 
		
		<h3>Aleks Krotoski</h3> 
		<p> 
			Technology section, The Guardian, Kings Place<br/> 
			90 York Way, London, N1 9AG
		</p> 
	</div>     
ENDTEXT
    Post.create(:title => "Aleks Contact Text", :name => "aleks-contact-text", :body => html, :body_rendered => html, :is_draft => true, :updated_at => Time.now, :created_at => Time.now)
  end
end

