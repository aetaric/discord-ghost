module Ghost
  module Helpers

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
    
    def humanize(secs)
      [[60, :s], [60, :m], [24, :h], [1000, :d]].map{ |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i}#{name}"
        end
      }.compact.reverse.join(' ')
    end
    
    def quotes
      result = $mysql.query("SELECT quote,source FROM quotes ORDER BY RAND() LIMIT 1;")
      quote_string = result.entries[0]["quote"] + " - " + result.entries[0]["source"]
      return quote_string
    end
    
    def get_clanid(server)
      statement = $mysql.prepare("SELECT * FROM guilds WHERE sid = ?")
      result = statement.execute(server.to_s)
      clans = []

      result.each do |r|
        clans.push r["d2_guild_id"]
      end

      return clans
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
  end
end
