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


class MarkLotsOfSpamComments < Sequel::Migration

  #in most cases, for the navbar, the titleized version of the tag name is fine.  But there's a couple that we need to override
  #and set explicitly, eg BBC, UKTI.
  
  class Comment < Sequel::Model;end
  
  def up
     
    bad_ips = [
      "116.205.84.251",
      "120.43.20.45",
      "156.34.147.70",
      "94.193.237.125",
      "175.44.19.166",
      "211.237.20.221",
      "175.44.16.163",
      "58.212.149.248",
      "175.44.22.126",
      "112.111.183.201",
      "58.22.159.227",
      "122.228.203.8",
      "121.229.87.229",
      "124.160.102.138",
      "59.60.120.185",
      "220.161.155.63",
      "110.178.50.212",
      "61.117.7.92",
      "218.6.70.6",
      "59.60.123.55",
      "121.229.85.251",
      "175.44.5.144",
      "58.212.147.251",
      "110.82.131.162",
      "125.78.222.6",
      "114.83.60.53",
      "220.161.154.54",
      "184.22.233.220",
      "110.178.25.165",
      "112.111.186.128",
      "222.221.142.197",
      "112.111.186.224",
      "220.161.139.74",
      "117.28.249.30",
      "175.42.86.126",
      "27.159.198.36",
      "59.58.154.41",
      "58.251.249.137",
      "184.22.76.148",
      "58.212.146.201",
      "59.60.125.75",
      "125.141.206.15",
      "116.77.72.113",
      "36.248.163.250",
      "110.85.71.119",
      "210.56.54.150",
      "171.36.19.172",
      "121.229.86.41",
      "175.44.10.224",
      "27.159.194.11",
      "121.205.209.69",
      "27.159.236.101",
      "116.52.176.90",
      "115.68.21.97",
      "117.26.125.150",
      "27.159.199.88",
      "65.49.2.177",
      "175.44.18.118",
      "110.90.84.180",
      "205.209.133.74",
      "124.128.0.78",
      "110.86.166.58",
      "110.85.73.220",
      "175.42.59.41",
      "118.94.89.27",
      "184.82.60.2",
      "180.136.127.225",
      "112.111.187.206",
      "27.159.210.243",
      "110.85.73.132",
      "210.172.220.9",
      "119.131.104.93",
      "59.60.120.69",
      "27.159.194.8",
      "27.159.211.104",
      "220.161.97.247",
      "61.144.117.218",
      "59.58.157.98",
      "27.159.218.150",
      "61.131.71.110",
      "121.205.248.199",
      "120.36.36.185",
      "222.217.121.251",
      "173.245.80.39",
      "36.248.163.6",
      "123.118.126.188",
      "220.200.33.11",
      "59.58.154.46",
      "121.204.201.122",
      "27.159.199.64",
      "67.198.244.122",
      "113.9.104.125",
      "222.47.31.176",
      "122.226.221.222",
      "120.37.210.128",
      "61.184.206.181",
      "120.39.116.160",
      "120.33.205.206",
      "59.58.137.12",
      "110.85.73.17",
      "117.26.202.165",
      "59.58.151.85",
      "175.42.86.27",
      "222.190.105.202",
      "116.52.185.162",
      "121.54.58.156",
      "120.85.140.40",
      "175.44.15.89",
      "109.172.66.61",
      "64.62.163.58",
      "180.140.122.28",
      "175.44.15.246",
      "110.86.164.79",
      "116.21.143.181",
      "121.162.131.11",
      "110.85.75.121",
      "27.159.199.50",
      "58.212.145.46",
      "218.66.250.106",
      "125.73.61.14",
      "69.195.139.213",
      "121.229.84.30",
      "114.228.142.151",
      "121.229.85.221",
      "110.85.68.10",
      "70.32.38.84",
      "121.229.81.254",
      "220.161.101.63",
      "110.86.164.165",
      "183.63.33.147",
      "175.44.14.167",
      "59.57.240.86",
      "121.229.85.99",
      "59.58.151.101",
      "113.13.36.101",
      "120.42.39.222",
      "59.58.153.160",
      "180.140.44.102",
      "209.236.115.165",
      "121.204.241.75",
      "218.86.103.29",
      "120.37.231.73",
      "61.144.157.23",
      "103.21.141.211",
      "110.86.184.78",
      "222.77.204.252",
      "114.228.133.223",
      "183.0.17.10",
      "113.16.67.80",
      "110.82.142.45",
      "117.26.225.6",
      "110.90.122.121",
      "61.144.131.225",
      "59.58.149.99",
      "27.159.235.254",
      "110.85.71.239",
      "59.58.149.46",
      "59.58.153.176",
      "175.42.81.65",
      "117.26.116.194",
      "175.42.41.6",
      "110.86.88.226",
      "121.205.239.148",
      "59.58.139.81",
      "173.252.231.227",
      "122.228.205.26",
      "59.60.121.74",
      "175.44.15.50",
      "208.53.151.172",
      "125.78.222.243",
      "218.86.103.29"
    ]
    
    spammed_comments = []
    bad_ips.each do |ip|
      comments = Comment.filter(:ip => ip).all;comments.size
      comments.each do |comment|
        comment.spam_checked = true
        comment.reported_as_spam = true
        comment.save
        spammed_comments << comment
      end
    end;puts "marked #{spammed_comments.size} comments as spam"
    
  end  
  
  def down
  end

end
