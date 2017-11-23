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

shard = ENV["SHARD"].to_i unless ENV["SHARD"].nil?
total_shards = ENV["TOTALSHARDS"].to_i unless ENV["TOTALSHARDS"].nil?
if shard.nil?
  shard = 0
  total_shards = 1
end

$bot = Discordrb::Commands::CommandBot.new token: ENV["DISCORD_TOKEN"], client_id: ENV["DISCORD_CLIENTID"], prefix: '!', shard_id: shard, num_shards: total_shards
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

def game
  $bot.game = quotes 
end

$bot.server_create do |event|
  puts "Ghost was added to server: #{event.server.name} (#{event.server.id})"
  bot_member = $bot.profile.on(event.server)
  event.server.channels.each do |channel|
    if bot_member.permission?(:send_messages, channel)
      channel.send_message "Thanks for adding me Guardian, but I won't function until I am configured!\n
I require only a few moments of your time to complete this important step.\n
Please take a moment to run the !configure *guild id* command in a text channel on your server.\n
*Example:* !configure 123456"
      break
    else
      puts "No permission in channel: #{channel.name}"
    end
  end
end

$bot.server_delete do |event|
  statement = $mysql.prepare("DELETE FROM servers WHERE sid=? LIMIT 1")
  statement.execute(event.server.id)
end

$bot.command(:commands, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  event.send_temporary_message "```
!botinfo     - Displays bot statistics and info.
!nightfall   - Pulls the realtime info about the current nightfall.
!newschannel - Sets the channel this is run in as your news channel. Any posts from Bungie's blog or @BungieHelp on twitter will be linked in this channel.
!claninfo    - Pulls the realtime info about your clan.
!engrams     - Pulls the realtime info about the clan engrams.```", 60.to_f
  temp_timers = Timers::Group.new
  temp_timers.after(60) { event.message.delete }
  temp_timers.wait
  event.drain
end

$bot.command(:botinfo, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  shard_value = (shard + 1).to_s + "/" + total_shards.to_s
  seconds = `ps -o etimes= -p '#{Process.pid}'`.strip.to_i
  event.channel.send_embed do |embed|
    embed.title = "Ghost"
    embed.description = "A discord bot for Destiny 2 clans"
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
    embed.add_field(name: "Author", value: "@aetaric#1427", inline: true)
    embed.add_field(name: "Servers", value: $bot.servers.count, inline: true)
    embed.add_field(name: "Shard", value: shard_value, inline: true)
    embed.add_field(name: "Uptime", value: humanize(seconds), inline: true)
    embed.add_field(name: "Library", value: "discordrb", inline: true)
    embed.add_field(name: "Support Server", value: "https://discord.gg/8My2HqS", inline: true)
  end
end

$bot.command(:configure, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event,guild_id|
  if event.author.defined_permission?(:administrator)
    if guild_id.nil?
      event.send_message "Guardian, I need the guild ID. Please provide it as an arguement to the command."
    else
      if guild_id.to_i
        statement = $mysql.prepare("INSERT INTO servers (sid,d2_guild_id,created_at,updated_at) VALUES (?, ?,NOW(),NOW())")
        result = statement.execute(event.channel.server.id.to_s,guild_id)

        event.send_message "Thank you Guardian! My commands are available via *!commands*."
      end
    end
  else
    event.send_message "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)"
  end
end

$bot.command(:newschannel, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  if event.author.defined_permission?(:administrator)
    statement = $mysql.prepare("UPDATE servers SET news_channel=? where sid=?")
    result = statement.execute(event.channel.id.to_s, event.channel.server.id.to_s)

    event.send_message "Guardian, Once news comes from Bungie, I will post it here."
  else
    event.send_message "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)"
  end
end

$bot.command(:claninfo, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  @clan = get_clanid event.channel.server.id

  @json = bungie_api_request "/Platform/GroupV2/#{@clan}/"

  @progression = @json["Response"]["detail"]["clanInfo"]["d2ClanProgressions"]["584850370"]

  channel = event.channel
  channel.send_embed do |embed|
    embed.title = @json["Response"]["detail"]["name"]
    embed.description = @json["Response"]["detail"]["about"]
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
    embed.add_field(name: "Level", value: @progression["level"], inline: true)
    embed.add_field(name: "Next Level", value: @progression["progressToNextLevel"].to_s + "/" + @progression["nextLevelAt"].to_s + " (" + (@progression["progressToNextLevel"].to_f / @progression["nextLevelAt"].to_f * 100.0).round(2).to_s + "%)", inline: true)
    embed.add_field(name: "Weekly Progress", value: @progression["weeklyProgress"].to_s + "/" + @progression["weeklyLimit"].to_s + " (" + (@progression["weeklyProgress"].to_f / @progression["weeklyLimit"].to_f * 100.0).round(2).to_s + "%)", inline: true)
  end
end

$bot.command(:nightfall, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  json = bungie_api_request "/Platform/Destiny2/Milestones/"

  modifiers = json["Response"]["2171429505"]['availableQuests'][0]['activity']['modifierHashes']
  hash = json["Response"]["2171429505"]['availableQuests'][0]['activity']['activityHash']

  @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityDefinition/#{hash}/"

  channel = event.channel
  channel.send_embed do |embed|
    embed.title = @lookup["Response"]["displayProperties"]["name"]
    embed.description = @lookup["Response"]["displayProperties"]["description"]
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["pgcrImage"])
    embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["displayProperties"]["icon"])
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
    modifiers.each do |mod|
      mod_info = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityModifierDefinition/#{mod.to_s}/"
      embed.add_field(name: mod_info["Response"]["displayProperties"]["name"], value: mod_info["Response"]["displayProperties"]["description"], inline: true)
    end
  end
end

$bot.command(:server, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', help_available: false) do |event|
  event.send_message event.channel.server.id
end

$bot.command(:engrams, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event|

  @clan = get_clanid event.channel.server.id

  json = bungie_api_request "/Platform/Destiny2/Clan/#{@clan}/WeeklyRewardState/"
  
  @crucible = false
  @trials = false
  @nightfall = false
  @raid = false
  
  json["Response"]["rewards"][0]["entries"].each do |entry|
    if entry["rewardEntryHash"] == 3789021730
      if entry["earned"] == true
        @nightfall = true
      end
    elsif entry["rewardEntryHash"] == 2112637710
      if entry["earned"] == true
        @trials = true
      end
    elsif entry["rewardEntryHash"] == 2043403989
      if entry["earned"] == true
        @raid = true
      end
    elsif entry["rewardEntryHash"] == 964120289
      if entry["earned"] == true
        @crucible = true
      end
    end
  end
  
  hash = json['Response']['milestoneHash']
  @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyMilestoneDefinition/#{hash.to_s}/"
  
  channel = event.channel
  channel.send_embed do |embed|
    embed.title = @lookup["Response"]["displayProperties"]["name"]
    embed.description = @lookup["Response"]["displayProperties"]["description"]
    embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["displayProperties"]["icon"])
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
    # 3789021730 - Nightfall
    if @nightfall
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["3789021730"]["displayProperties"]["name"], value: "Available", inline: true)
    else
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["3789021730"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
    end
    # 2112637710 - Trials
    if @trials
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2112637710"]["displayProperties"]["name"], value: "Available", inline: true)
    else
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2112637710"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
    end
    # 2043403989 - Raid
    if @raid
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2043403989"]["displayProperties"]["name"], value: "Available", inline: true)
    else
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2043403989"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
    end
    # 964120289 - Crucible
    if @crucible
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["964120289"]["displayProperties"]["name"], value: "Available", inline: true)
    else
      embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["964120289"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
    end
  end
end

def bungie_api_request(path)
  uri = URI.parse($base_url + path)
  request = Net::HTTP::Get.new(uri)
  request["X-Api-Key"] = ENV["BUNGIE_API"]
  
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  
  return JSON.load(response.body)
end

def news
  query = $mysql.query("SELECT news_channel FROM servers;")
  @channels = []
  query.each do |r|
    if !r["news_channel"].nil?
      @channels.push r["news_channel"]
    end
  end

  tweets = $twitter.user_timeline("bungiehelp")
  tweets.each do |tweet|
    statement = $mysql.prepare("SELECT tweet_id FROM bungie_help WHERE tweet_id=?;")
    result = statement.execute(tweet.id)
    if result.entries.empty?
      insert_statement = $mysql.prepare("INSERT INTO bungie_help (tweet_id,text,url) VALUES (?,?,?);")
      insert_statement.execute(tweet.id, tweet.text, tweet.url.to_s)
      @channels.each do |channel|
        $bot.channel(channel).send_embed do |embed|
          embed.title = tweet.user.name + " (@#{tweet.user.screen_name})"
          embed.description = tweet.text
          embed.url = tweet.url.to_s
          embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: tweet.user.profile_image_url.to_s)
          embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
          embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
        end
        sleep 1
      end
    end
  end 

  url = 'https://www.bungie.net/en-us/Rss/NewsByCategory'
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      statement = $mysql.prepare("SELECT guid FROM bungie_news WHERE guid=?;")
      result = statement.execute(item.guid.content)
      if result.entries.empty?
        insert_statement = $mysql.prepare("INSERT INTO bungie_news (guid,title,link,description) VALUES (?,?,?,?);")
        insert_statement.execute(item.guid.content, item.title, item.link, item.description)
        @channels.each do |channel|
          $bot.channel(channel).send_embed do |embed|
            embed.title = item.title
            embed.description = item.description
            embed.url = item.link
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
          end
        end
      end
      sleep 1
    end
  end
end

def humanize(secs)
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

def quotes
  result = $mysql.query("SELECT quote,source FROM quotes ORDER BY RAND() LIMIT 1;")
  quote_string = result.entries[0]["quote"] + " - " + result.entries[0]["source"]
  return quote_string
end

def get_clanid(server)
  statement = $mysql.prepare("SELECT * FROM servers WHERE sid = ?")
  result = statement.execute(server.to_s)
  return result.first["d2_guild_id"]
end

def graphite(shard)
  $graphite.metrics("ghost.servers.shard.#{shard}" => $bot.servers.count) unless $graphite.nil?
end

$bot.run :async
$bot.ready { game }

$timers = Timers::Group.new
timer = $timers.every(60) { game }
news_timer = $timers.every(60) { news }
graphtie_timer = $timers.every(60) { graphite(shard) }
loop { $timers.wait }

