module Ghost
  module TimerHelpers
    def news
      query = $mysql.query("SELECT news_channel FROM servers;")
      @channels = []
      query.each do |r|
        if !r["news_channel"].nil?
          @channels.push r["news_channel"]
        end
      end

      begin
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
      rescue Discordrb::Errors::NoPermission => e
        puts "Error occured while posting news in #{bot.channel(channel).server.id}"
      end
    end

    def game
      $bot.game = quotes
    end

    def graphite(shard)
      $graphite.metrics("ghost.servers.shard.#{shard}" => $bot.servers.count) unless $graphite.nil?
    end

    def discordbots(shard, total_shards, dbl_token)
      body = {}
      body["server_count"] = $bot.servers.count
      body["shard_id"] = shard
      body["shard_count"] = total_shards

      uri = URI.parse("https://discordbots.org/api/bots/#{$bot.profile.id}/stats")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "#{dbl_token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.dump(body)

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    end
  end
end
