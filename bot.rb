#!/usr/bin/ruby

require 'discordrb'
require 'net/http'
require 'uri'
require 'json'
require 'timers'
require 'mysql2'
require 'rss'
require 'open-uri'
require 'twitter'
require 'graphite-api'
require 'graphite-api/core_ext/numeric'
require 'htmlentities'

# Load non-Discordrb modules
Dir['modules/*.rb'].each { |mod| load mod }

include Ghost::Helpers
include Ghost::BungieAPI
include Ghost::TimerHelpers

module Ghost

  $shard = ENV["SHARD"].to_i unless ENV["SHARD"].nil?
  $total_shards = ENV["TOTALSHARDS"].to_i unless ENV["TOTALSHARDS"].nil?
  if $shard.nil?
    $shard = 0
    $total_shards = 1
  end
  
  $bot = Discordrb::Commands::CommandBot.new token: ENV["DISCORD_TOKEN"], client_id: ENV["DISCORD_CLIENTID"], prefix: '!', shard_id: $shard, num_shards: $total_shards
  $mysql = Mysql2::Client.new( :host => ENV["DB_HOST"], :username => ENV["DB_USER"], :password => ENV["DB_PASSWORD"], :port => ENV["DB_PORT"], :database => ENV["DATABASE"], :reconnect => true)
  
  begin
    $graphite = GraphiteAPI.new( graphite: ENV["GRAPHITE_HOST"] )
  rescue StandardError => e
    $graphite = nil
  end
  
  $twitter = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
    config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
    config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
    config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
  end
  
  $bot.bucket :D2, limit: 3, time_span: 60, delay: 10
  $bot.bucket :general, limit: 3, time_span: 60, delay: 10
  
  $base_url = "https://www.bungie.net"
  
  # Discord commands
  module DiscordCommands; end
  Dir['modules/commands/*.rb'].each { |mod| load mod }
  DiscordCommands.constants.each do |mod|
    $bot.include! DiscordCommands.const_get mod
  end

  # Discord events
  module DiscordEvents; end
  Dir['modules/events/*.rb'].each { |mod| load mod }
  DiscordEvents.constants.each do |mod|
    $bot.include! DiscordEvents.const_get mod
  end

  $bot.run :async
  $bot.ready { game }
  
  $timers = Timers::Group.new
  timer = $timers.every(60) { game }
  news_timer = $timers.every(60) { news }
  graphtie_timer = $timers.every(60) { graphite($shard) }
  discordbots_timer = $timers.every(120) { discordbots($shard, $total_shards, ENV["DBL_TOKEN"]) }
  loop { $timers.wait }

end
