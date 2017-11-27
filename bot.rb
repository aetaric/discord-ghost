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
!item        - Searches for the item passed after the command.
!nightfall   - Pulls the realtime info about the current nightfall.
!newschannel - Sets the channel this is run in as your news channel. Any posts from Bungie's blog or @BungieHelp on twitter will be linked in this channel.
!claninfo    - Pulls the realtime info about your clan.
!engrams     - Pulls the realtime info about the clan engrams.```", 60.to_f
  temp_timers = Timers::Group.new
  temp_timers.after(60) { event.message.delete }
  temp_timers.wait
  event.drain
end

$bot.command(:eval, help_available: false) do |event, *code|
   break unless event.user.id == 188105444365959170
   begin
     eval code.join(' ')
   rescue => e
     "An error occurred 😞 ```#{e}```"
   end
end

$bot.command(:botinfo, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
  shard_value = (shard + 1).to_s + "/" + total_shards.to_s
  seconds = `ps -o etimes= -p '#{Process.pid}'`.strip.to_i
  rev = `git rev-parse HEAD`.strip.split(//).first(9).join("")
  event.channel.send_embed do |embed|
    embed.title = "Ghost"
    embed.description = "A discord bot for Destiny 2 clans"
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
    embed.add_field(name: "Author", value: "@aetaric#1427", inline: true)
    embed.add_field(name: "Servers", value: $bot.servers.count, inline: true)
    embed.add_field(name: "Shard", value: shard_value, inline: true)
    embed.add_field(name: "Uptime", value: humanize(seconds), inline: true)
    embed.add_field(name: "Version", value: rev, inline: true)
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

$bot.command(:item, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event,*search_term|
  if search_term.nil?
    event.send_message "Guardian, You need to tell me what you are looking for. try:\n !item Lincoln Green"
    break
  end
  if search_term.join("%20").length < 3
    event.send_message "Guardian, I need 3 or more letters to search the archives."
    break
  end

  item_hash = nil

  if search_term[(search_term.length - 1)] =~ /\A\d+\z/ ? true : false
    item_hash = search_term.pop
  end
  if item_hash.nil?
    search = search_term.join("%20")
    search_response = bungie_api_request "/Platform/Destiny2/Armory/Search/DestinyInventoryItemDefinition/#{search}/"
    if search_response["Response"]["results"]["totalResults"] == 0
      event.send_message "Guardian, I couldn't find an item with that name."
      break
    elsif search_response["Response"]["results"]["totalResults"] > 1
      results = []
      search_response["Response"]["results"]["results"].each do |result|
        results.push result["displayProperties"]["name"] + " " + result["hash"].to_s
      end
      event.send_message "Guardian, I found the following results for that search. Please try again with one of the items below.\n#{results.join("\n")}"
      break
    end

    item_hash = search_response["Response"]["results"]["results"][0]["hash"]
  end
  
  item_response = bungie_api_request "/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{item_hash}/"

  event.channel.send_embed do |embed|
    embed.title = item_response["Response"]["displayProperties"]["name"]
    embed.description = item_response["Response"]["displayProperties"]["description"]
    embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + item_response["Response"]["displayProperties"]["icon"])
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + item_response["Response"]["screenshot"])
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
    embed.color = Discordrb::ColourRGB.new(color_map(item_response["Response"]["inventory"]["tierType"])).combined
    embed.add_field(name: "Type", value: item_response["Response"]["itemTypeDisplayName"], inline: true)
    embed.add_field(name: "Tier", value: item_response["Response"]["inventory"]["tierTypeName"], inline: true)
    if !class_map(item_response["Response"]["quality"]["infusionCategoryName"]).nil?
      embed.add_field(name: "Class", value: class_map(item_response["Response"]["quality"]["infusionCategoryName"]), inline: true)
    end

    if item_response["Response"]["itemType"] == 2
      # Armor
      defense, mobility, resilience, recovery = armor_stats(item_response["Response"]["stats"]["stats"])
      embed.add_field(name: defense["name"], value: defense["value"], inline: true)
      embed.add_field(name: mobility["name"], value: mobility["value"], inline: true)
      embed.add_field(name: resilience["name"], value: resilience["value"], inline: true)
      embed.add_field(name: recovery["name"], value: recovery["value"], inline: true)
    elsif item_response["Response"]["itemType"] == 3
      # weapon
      stats = weapon_stats(item_response["Response"]["stats"]["stats"])
      stats.each do |_,value|
        embed.add_field(name: value["name"], value: value["value"], inline: true)
      end
    else
      # something else
      event.send_message "Guardian, That looks to be something other than a weapon or armor..."
      break
    end

    if !item_response["Response"]["sockets"]["socketEntries"].nil?
      item_response["Response"]["sockets"]["socketEntries"].each do |socket|
        if !socket["reusablePlugItems"].empty?
          name = ""
          description = ""
          socket["reusablePlugItems"].each_with_index do |plug,index|
            plug_response = bungie_api_request "/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{plug['plugItemHash']}/"
            name += plug_response["Response"]["displayProperties"]["name"]
            description += plug_response["Response"]["displayProperties"]["description"]
            if (index + 1) != socket["reusablePlugItems"].length
              name += " | "
              description += " \n\n"
            end
          end

          embed.add_field(name: name, value: description, inline: true)
        end
      end
    end
  end
end

def armor_stats(stats)
  defense = {"name" => "Defense"}
  mobility = {"name" => "Mobility"}
  resilience = {"name" => "Resilience"}
  recovery = {"name" => "Recovery"}

  # Defense
  if !stats["3897883278"].nil?
    defense["value"] = "#{stats["3897883278"]["minimum"]} - #{stats["3897883278"]["maximum"]}"
  else
    defense["value"] = "0"
  end

  # Mobility
  if !stats["2996146975"].nil?
    mobility["value"] = stats["2996146975"]["value"]
  else
    mobility["value"] = 0
  end

  # Resilience
  if !stats["392767087"].nil?
    resilience["value"] = stats["392767087"]["value"]
  else
    resilience["value"] = 0
  end

  # Recovery
  if ! stats["1943323491"].nil?
    recovery["value"] = stats["1943323491"]["value"]
  else
    recovery["value"] = 0
  end

  return defense, mobility, resilience, recovery
end

def weapon_stats(stats)
  wep_stats = {}
  attack = {"name" => "Attack"}
  magazine = {"name" => "Magazine"}
  rpm = {"name" => "RPM"}
  charge_time = {"name" => "Charge Time"}
  blast_radius = {"name" => "Blast Radius"}
  aim_assist = {"name" => "Aim Assist"}

  impact = {"name" => "Impact"}
  range = {"name" => "Range"}
  stability = {"name" => "Stability"}
  reload_speed = {"name" => "Reload Speed"}
  handling = {"name" => "Handling"}
  velocity = {"name" => "Velocity"}
  
  # Attack
  if !stats["1480404414"].nil?
    attack["value"] = "#{stats["1480404414"]["minimum"]} - #{stats["1480404414"]["maximum"]}"
    wep_stats["attack"] = attack
  else
    attack["value"] = 0
  end

  # Magazine
  if !stats["3871231066"].nil?
    magazine["value"] = "#{stats["3871231066"]["value"]}"
    wep_stats["magazine"] = magazine
  else
    magazine["value"] = 0
  end

  # RPM
  if !stats["4284893193"].nil?
    rpm["value"] = "#{stats["4284893193"]["value"]}"
    wep_stats["rpm"] = rpm
  else
    rpm["value"] = 0
  end

  # Charge Time
  if !stats["2961396640"].nil?
    charge_time["value"] = "#{stats["2961396640"]["value"]}"
    wep_stats["charge_time"] = charge_time
  else
    charge_time["value"] = 0
  end

  # Blast Radius
  if !stats["3614673599"].nil?
    blast_radius["value"] = "#{stats["3614673599"]["value"]}"
    wep_stats["blast_radius"] = blast_radius
  else
    blast_radius["value"] = 0
  end

  # Aim Assist
  if !stats["1345609583"].nil?
    aim_assist["value"] = "#{stats["1345609583"]["value"]}"
    wep_stats["aim_assist"] = aim_assist
  else
    aim_assist["value"] = 0
  end

  # Impact
  if !stats["4043523819"].nil?
    impact["value"] = "#{stats["4043523819"]["value"]}"
    wep_stats["impact"] = impact
  else
    impact["value"] = 0
  end

  # Range
  if !stats["1240592695"].nil?
    range["value"] = "#{stats["1240592695"]["value"]}"
    wep_stats["range"] = range
  else
    range["value"] = 0
  end

  # Stability
  if !stats["155624089"].nil?
    stability["value"] = "#{stats["155624089"]["value"]}"
    wep_stats["stability"] = stability
  else
    stability["value"] = 0
  end

  # Reload Speed
  if !stats["4188031367"].nil?
    reload_speed["value"] = "#{stats["4188031367"]["value"]}"
    wep_stats["reload_speed"] = reload_speed
  else
    reload_speed["value"] = 0
  end

  # Handling
  if !stats["943549884"].nil?
    handling["value"] = "#{stats["943549884"]["value"]}"
    wep_stats["handling"] = handling
  else
    handling["value"] = 0
  end

  # Velocity
  if !stats["2523465841"].nil?
    velocity["value"] = "#{stats["2523465841"]["value"]}"
    wep_stats["velocity"] = velocity 
  else
    velocity["value"] = 0
  end

  return wep_stats
end

def class_map(class_text)
  case class_text
  when /warlock/
    return "Warlock"
  when /titan/
    return "Titan"
  when /hunter/
    return "Hunter"
  else
    return nil
  end
end

def color_map(tier)
  case tier
  when 1
    return 0x000000
  when 2
    return 0xc3bcb4
  when 3
    return 0x306c39
  when 4
    return 0x5076a3
  when 5
    return 0x542f65
  when 6
    return 0xceae33
  else 
    return 0x36393e
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

def discordbots(shard, total_shards, dbl_token)
  body = {}
  body["server_count"] = $bot.servers
  body["shard_id"] = shard
  body["shard_count"] = total_shards

  uri = URI.parse("https://discordbots.org/api/bots/#{$bot.profile.id}/stats")
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "#{dbl_token}"
  request.body = JSON.dump(body)

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
end

$bot.run :async
$bot.ready { game }

$timers = Timers::Group.new
timer = $timers.every(60) { game }
news_timer = $timers.every(60) { news }
graphtie_timer = $timers.every(60) { graphite(shard) }
discordbots_timer = $timers.every(120) { discordbots(shard, total_shards, ENV["DBL_TOKEN"]) }
loop { $timers.wait }

