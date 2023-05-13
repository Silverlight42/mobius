module Mobius
  class Teams
    @teams = [
      {
        id: 0,
        name: "Nod",
        abbreviation: "Nod",
        color: "04"
      },
      {
        id: 1,
        name: "GDI",
        abbreviation: "GDI",
        color: "08,15"
      },
      {
        id: 2,
        name: "Neutral",
        abbreviation: "Neu",
        color: "09"
      }
    ]

    @team_first_picking = 0

    def self.init
      log "INIT", "Loading Teams..."

      read_config
    end

    def self.teardown
    end

    def self.read_config(path: "#{ROOT_PATH}/conf/teams.json")
      raise "Teams config file not found at: #{path}" unless File.exist?(path)

      json = File.read(path)

      begin
        result = config_valid?(JSON.parse(json, symbolize_names: true))
        @teams = result if result
      # FIXME: Find the correct name for this exception
      rescue JSONParserException => e
        pp e
        abort "Failed to parse #{path}"
      end
    end

    def self.config_valid?(array)
      return false unless array.is_a?(Array)

      array
    end

    def self.id_from_name(team)
      return team if team.is_a?(Integer)

      @teams.find { |hash| hash[:name].downcase == team.to_s.downcase || hash[:abbreviation].downcase == team.to_s.downcase }
    end

    def self.name(team)
      hash = nil
      hash = id_from_name(team) if team.is_a?(String)
      hash = @teams.find { |h| h[:id] == team } if team.is_a?(Integer)

      if hash
        hash[:name]
      else
        "Unknown"
      end
    end

    def self.abbreviation(team)
      hash = nil
      hash = id_from_name(team) if team.is_a?(String)
      hash = @teams.find { |h| h[:id] == team } if team.is_a?(Integer)

      if hash
        hash[:abbreviation]
      else
        "Unk"
      end
    end

    def self.color(team)
      hash = id_from_name(team)

      if hash
        hash[:color] || hash[:colour]
      else
        "01"
      end
    end

    def self.list
      @teams
    end

    def self.colorize_name(team)
      IRC.colorize(color(team), name(team))
    end

    def self.colorize_abbreviation(team)
      IRC.colorize(color(team), abbreviation(team))
    end

    def self.skill_sort_teams
      team_zero = []
      team_one = []
      team_zero_rating = 0.0
      team_one_rating = 0.0
      list = []
      team_picking = @team_first_picking

      PlayerData.player_list.select(&:ingame?).each do |player|
        rating = Database::Rank.first(name: player.name.downcase)&.skill || PlayerData::DEFAULT_SKILL

        list << [player, rating]
      end

      list.sort_by! { |l| [l[1], l[0].name.downcase] }.reverse

      list.each do |player, rating|
        (team_picking.zero? ? team_zero : team_one) << player
        team_zero_rating += rating if team_picking.zero?
        team_one_rating += rating unless team_picking.zero?

        team_picking = team_picking.zero? ? 1 : 0
      end

      [team_zero, team_one, team_zero_rating, team_one_rating]
    end

    def self.team_first_picking
      @team_first_picking
    end

    def self.team_first_picking=(n)
      @team_first_picking = n
    end
  end
end
