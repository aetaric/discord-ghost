module Ghost
  module DiscordCommands
    module Item
      extend Discordrb::Commands::CommandContainer

        command(:item, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event,*search_term|
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

       
    end
  end
end
