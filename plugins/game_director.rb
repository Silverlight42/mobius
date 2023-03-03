mobius_plugin(name: "GameDirector", version: "0.0.1") do
  def donations_available?(player)
    donate_limit = MapSettings.get_map_setting(:donatelimit)
    map = ServerStatus.get(:current_map)
    map_elapsed_time = monotonic_time.to_i - ServerStatus.get(:map_start_time)

    if (donate_limit != 0 && map_elapsed_time < donate_limit * 60)
      remaining = donate_limit - (map_elapsed_time / 60.0).round;

      page_player(player.name, "[MOBIUS] Donations are not allowed on #{map} in the first #{donate_limit} minutes. You have to wait #{remaining} more minutes.")

      return false
    end

    return true
  end

  command(:remix, arguments: 0, help: "!remix NOW - Shuffle teams", groups: [:admin, :mod]) do |command|
    if command.arguments.first == "NOW"
      log "#{command.issuer.name} remixed teams"
      remix_teams
      broadcast_message("Teams have been remixed")
    else
      page_player(player.name, "Use !remix NOW to truely remix teams")
    end
  end

  command(:gameover, arguments: 1, help: "!gameover NOW", groups: [:admin, :mod, :director]) do |command|
    if command.arguments.first == "NOW"
      log "#{command.issuer.name} ended the game"
      RenRem.cmd("gameover")
    else
      page_player(player.name, "Use !gameover NOW to truely end the game")
    end
  end

  command(:setnextmap, aliases: [:snm], arguments: 1, help: "!setnextmap <mapname>", groups: [:admin, :mod, :director]) do |command|
    # message_player(command.issuer.name, "Not yet implemented!")

    maps = ServerConfig.installed_maps.select do |map|
      map.downcase.include?(command.arguments.first.downcase)
    end

    if maps.count > 1
      page_player(command.issuer.name, "More than one map matched search, found: #{maps.join(', ')}")
    elsif maps.count.zero?
      page_player(command.issuer.name, "No map matched: #{command.arguments.first}")
    else
      original_map = ServerConfig.rotation.rotate(ServerStatus.get(:current_map_number) + 1)&.first
      array_index = ServerConfig.rotation.index(original_map)

      RenRem.cmd("mlistc #{array_index} #{maps.first}")

      ServerConfig.data[:nextmap_changed_id] = array_index
      ServerConfig.data[:nextmap_changed_mapname] = original_map

      # Update rotation
      log "Switching #{original_map} with #{maps.first}"
      ServerConfig.rotation[array_index] = maps.first

      broadcast_message("[GameDirector] Set next map to #{maps.first}")
    end
  end

  command(:maps, arguments: 0, help: "!maps", groups: [:admin, :mod, :director]) do |command|
    maps = ServerConfig.installed_maps

    maps.each_slice(6) do |slice|
      broadcast_message(
        slice.join(", ")
      )
    end
  end

  command(:time, arguments: 1, help: "!time 5m", groups: [:admin, :mod, :director]) do |command|
    match_data = command.arguments.first.match(/(\d+)([smh])/)

    # FIXME: Specifying time without s/m causes error
    time = match_data[1].to_i
    unit = match_data[2]

    hardcap = 2 * 60 * 60 # 2 hours

    if time <= 0
      page_player(command.issuer.name, "Time must be greater than 0!")
    elsif (unit == "s" && time >= hardcap) || (unit == "m" && time * 60 >= hardcap)
      log "Player #{command.issuer.name} attempted to set the game clock to #{match_data[0]}"
      page_player(command.issuer.name, "Game clock may not be set greater than 2 hours!")
    else
      case unit
      when "s"
        RenRem.cmd("time #{time}")
        log "#{command.issuer.name} has set the game clock to #{time} seconds"
        broadcast_message("[GameDirector] #{command.issuer.name} has set the game clock to #{time} seconds")
      when "m"
        RenRem.cmd("time #{time * 60}")
        log "#{command.issuer.name} has set the game clock to #{time} minutes"
        broadcast_message("[GameDirector] #{command.issuer.name} has set the game clock to #{time} minutes")
      else
        page_player(command.issuer.name, "Time unit must be s for seconds and m for minutes. Example: !time 15m")
      end
    end
  end

  command(:force_team_change, aliases: [:ftc], arguments: 2, help: "!force_team_change <nickname> <team name or id>", groups: [:admin, :mod]) do |command|
    player = PlayerData.player(PlayerData.name_to_id(command.arguments.first, exact_match: false))
    team = command.arguments.last

    begin
      team = Integer(team)
    rescue ArgumentError
      team = Teams.id_from_name(team)
      team = team[:id] if team
    end

    if player
      if team.is_a?(Integer)
        broadcast_message("[GameDirector] Player #{player.name} has changed teams")
        player.set_value(:manual_team, true)
        player.change_team(team)
      else
        page_player(command.issuer.name, "Failed to detect team for: #{command.arguments.last}, got #{team}, try again.")
      end
    else
      page_player(command.issuer.name, "Player is not in game or name is not unique!")
    end
  end

  command(:revive, arguments: 2, help: "!revive <team> <building preset>", groups: [:admin, :mod]) do |command|
    team = command.arguments.first
    preset = command.arguments.last

    begin
      team = Integer(team)
    rescue ArgumentError
      team = Teams.id_from_name(team)
      team = team[:id] if team
    end

    if team.is_a?(Integer)
      page_player(command.issuer.name, "Attempting to revive building for team #{Teams.name(team)} from preset: #{preset}")
      RenRem.cmd("revivebuildingbypreset #{team} #{preset}")
    else
      page_player(command.issuer.name, "Failed to detect team for: #{command.arguments.first}, got #{team}, try again.")
    end
  end

  command(:spawn, arguments: 2, help: "!spawn <z> <vehicle preset>", groups: [:admin, :mod]) do |command|
    z = Integer(command.arguments.first)
    preset = command.arguments.last

    page_player(command.issuer.name, "Attempting to spawn vehicle from preset: #{preset}")
    RenRem.cmd("SpawnVehicle #{command.issuer.id} #{z} #{preset}")
  end

  command(:spectate, arguments: 1, help: "!spectate <name>", groups: [:admin, :mod]) do |command|
    player = PlayerData.player(PlayerData.name_to_id(command.arguments.first, exact_match: false))

    if player
      RenRem.cmd("toggle_spectator #{player.id}")
      page_player(command.issuer.name, "#{player.name} is now spectating.")
    else
      page_player(command.issuer.name, "Player is not in game or name is not unique!")
    end
  end

  command(:nextmap, aliases: [:n, :next], arguments: 0, help: "!nextmap") do |command|
    map = ServerConfig.rotation.rotate(ServerStatus.get(:current_map_number) + 1)&.first

    broadcast_message(map)
  end

  command(:rotation, aliases: [:r, :rot], arguments: 0, help: "!rotation") do |command|
    maps = ServerConfig.rotation.rotate((ServerStatus.get(:current_map_number) + 1))

    maps.each_slice(6) do |slice|
      broadcast_message(
        slice.join(", ")
      )
    end
  end

  command(:donate, aliases: [:d], arguments: 2, help: "!donate <nickname> <amount>") do |command|
    player = PlayerData.player(PlayerData.name_to_id(command.arguments.first, exact_match: false))
    amount = command.arguments.last.to_i

    if player
      if amount.positive?
        if command.issuer.team == player.team && command.issuer.name != player.name
          if donations_available?(command.issuer)
            RenRem.cmd("donate #{command.issuer.id} #{player.id} #{amount}")

            page_player(command.issuer.name, "You have donated #{amount} credits to #{player.name}")
            page_player(player.name, "#{command.issuer.name} has donated #{amount} credits to you")
          end
        elsif command.issuer.name == player.name
          page_player(command.issuer.name, "You cannot donate to yourself")
        else
          page_player(command.issuer.name, "Can only donate to players on your team")
        end
      else
        page_player(command.issuer.name, "Cannot donate nothing!")
      end
    else
      page_player(command.issuer.name, "Player not in game or name is not unique!")
    end
  end

  # FIXME:
  command(:teamdonate, aliases: [:td], arguments: 1, help: "!teamdonate <amount>") do |command|
    mates  = PlayerData.player_list.select { |ply| ply.ingame? && ply.team == command.issuer.team && ply != command.issuer }
    amount = command.arguments.last.to_i

    if mates.count.positive?
      if amount.positive?
        if donations_available?(command.issuer)
          slice = (amount / mates.count.to_f).floor

          mates.each do |mate|
            RenRem.cmd("donate #{command.issuer.id} #{mate.id} #{slice}")

            page_player(mate.name, "#{command.issuer.name} has donated #{slice} credits to you")
          end

          # FIXME: Sometimes this message is not delivered!
          page_player(command.issuer.name, "You have donated #{amount} credits to your team")
        end
      else
        page_player(command.issuer.name, "Cannot donate nothing!")
      end
    else
      page_player(command.issuer.name, "You are the only one on your team!")
    end
  end

  command(:stuck, arguments: 0, help: "Become unstuck, maybe.") do |command|
    broadcast_message("!stuck not available. Use !killme if needed.")
  end

  command(:killme, arguments: 0, help: "Kill yourself") do |command|
    RenRem.cmd("kill #{command.issuer.id}")

    broadcast_message("#{command.issuer.name} has respawned")
  end

  command(:ping, arguments: 0..1, help: "!ping [<nickname>]") do |command|
    if command.arguments.first.empty?
      player = PlayerData.player(PlayerData.name_to_id(command.issuer.name))

      if player
        broadcast_message("#{command.issuer.name}'s ping: #{player.ping}ms")
      else
        broadcast_message("Failed to find player.")
      end
    else
      player = PlayerData.player(PlayerData.name_to_id(command.arguments.first, exact_match: false))

      if player
        broadcast_message("#{player.name}'s ping: #{player.ping}ms")
      else
        broadcast_message("Player not in game or name is not unique!")
      end
    end
  end
end
