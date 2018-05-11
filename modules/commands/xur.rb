module Ghost
  module DiscordCommands
    module Xur
      extend Discordrb::Commands::CommandContainer

      command(:xur, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the items Xur has for sale. If he's not around. Displays the time he will be back.") do |event|
        result = $mysql.query('SELECT membership_id FROM oauth where deleted != 1 LIMIT 1')
        oauth = result.first
        
        begin
          membership_data = bungie_api_request "/Platform/User/GetMembershipsById/#{oauth['membership_id']}/-1/"
          resolved_data = membership_data['Response']['destinyMemberships'][0]
          profile = bungie_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/?components=200"
          character = profile['Response']['characters']['data'].keys[0]
          vendor_request = bungie_authenticated_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/Character/#{character}/Vendors/?components=400,401,402"
        rescue NoMethodError => e
          if membership_data['ErrorStatus'] != "Success"
            event.channel.send_message "Error getting data from Bungie: #{membership_data['Message']}"
          elsif resolved_data['ErrorStatus'] != "Success"
            event.channel.send_message "Error getting data from Bungie: #{resolved_data['Message']}"
          elsif profile['ErrorStatus'] != "Success"
            event.channel.send_message "Error getting data from Bungie: #{profile['Message']}"
          elsif character['ErrorStatus'] != "Success"
            event.channel.send_message "Error getting data from Bungie: #{character['Message']}"
          elsif vendor_request['ErrorStatus'] != "Success"
            event.channel.send_message "Error getting data from Bungie: #{vendor_request['Message']}"
          end
        end
        
        xur_data = vendor_request['Response']['vendors']['data']['2190858386']
        xur_sales = vendor_request['Response']['sales']['data']['2190858386']['saleItems']
        xur_definition = bungie_api_request("/Platform/Destiny2/Manifest/DestinyVendorDefinition/2190858386/")['Response']['displayProperties']

        now = DateTime.now.to_time
        refresh_time = DateTime.parse(xur_data['nextRefreshDate'].gsub(/Z/, '-08:00')).to_time

        remaining_time = refresh_time - now

        if (remaining_time / 3600) <= 72.0
          channel = event.channel
          channel.send_embed do |embed|
            embed.title = xur_definition['name']
            embed.description = xur_definition['description']
            embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['icon'])
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['largeIcon'])
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0xceae33).combined
            embed.add_field(name: "Xur is away", value: "Xur will return in #{humanize(remaining_time.to_i)}", inline: true)
          end
        else
          items = []
          xur_sales.keys.each do |sale|
            if xur_sales[sale]['itemHash'] != 759381183
              if xur_sales[sale]['saleStatus'] == 0
                item = bungie_api_request("/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{xur_sales[sale]['itemHash']}/")['Response']['displayProperties']
                item_hash = {'name' => item['name'], 'description' => item['description']}
                items.push item_hash 
              end
            end
          end

          uri = URI.parse("http://whatsxurgot.com/weekly/data.json")
          response = Net::HTTP.get_response(uri)
          locations = JSON.load(response.body)['XurLocations']
          xur_location = {}
          locations.each do |location|
            if location['currentLocation'] == true
              xur_location = location
            end
          end

          channel = event.channel
          begin
            channel.send_embed do |embed|
              embed.title = xur_definition['name']
              embed.description = xur_definition['description']
              embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['icon'])
              embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['largeIcon'])
              embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
              embed.color = Discordrb::ColourRGB.new(0xceae33).combined
             
              embed.add_field(name: "Time Remaining", value: "Xur leaves in #{humanize((remaining_time - 259200).to_i)}.", inline: false)
              embed.add_field(name: "Location", value: "#{xur_location['world']} // #{HTMLEntities.new.decode xur_location['region']}\n • #{HTMLEntities.new.decode xur_location['description']}", inline: false)
              items.each do |item|
                embed.add_field(name: item['name'], value: item['description'], inline: true)
              end
            end
          rescue Discordrb::Errors::NoPermission => e
            event.author.pm "Guardian, I don't have permission to speak in that channel. Please make sure I can send messages and embed links."
          end
        end
      end
    end
  end
end
