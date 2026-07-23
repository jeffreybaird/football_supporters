# frozen_string_literal: true

module Quiz
  # Idempotent seed for the initial league and its clubs. This is the *initial
  # content* for the DB-backed League/Team model — the app reads teams from the
  # database, never from here. Run via `rake db:seed`; the test suite runs it
  # once after migrating. Re-running upserts, so it is safe to run repeatedly.
  #
  # Adding another league later means adding another entry here (or inserting
  # rows by any other means) — no code changes elsewhere.
  module Seed
    module_function

    LEAGUE = {
      slug: "premier-league", name: "Premier League", season: "2026-27",
      chooser_threshold: Data::CHOOSER_THRESHOLD, max_choices: Data::MAX_CHOICES, amplify: Data::AMPLIFY
    }.freeze

    # name, [vibe, play, ethics, fanbase], crest file, blurb — in display order.
    TEAMS = [
      ["Man City", [10.0, 5, 2, 3], "8456-Man City.png",
       "Crowded beneath their blue banners, the voices of Manchester City fans echo through The Etihad. The lean years are a distant memory, and their newer fans don't remember them. Their team has been transformed by Abu Dhabi money and is unrecognizable compared to its fallow history. Some call it sports washing, others, glory-hunting. For City supporters, it's loyalty rewarded, no matter what outsiders say."],
      ["Liverpool", [9.6, 9, 6, 7], "8650-Liverpool.png",
       "Every fanbase claims their atmosphere is special. At Anfield it's occasionally, annoyingly, true. The European nights are the thing: Kop in full voice, some doomed away side conceding twice in five minutes. Rival fans find the whole “This Means More” act insufferable, and Liverpool fans know that, and don't care. The self-mythologizing is part of the club. So is the fact that, every so often, the myth actually delivers. When you support Liverpool, You'll Never Walk Alone."],
      ["Arsenal", [10.0, 5, 5, 3], "9825-Arsenal.png",
       "Arsenal fans spent years getting laughed at for “banter era” collapses, so the title means more than the trophy itself. It's vindication. Of course, being Arsenal fans, they've already moved on to arguing about it online. Every dropped point still gets a fifteen-minute video essay by Tuesday."],
      ["Man United", [10.0, 6, 4, 8], "10260-Man United.png",
       "Every August, United fans decide this is the year. It usually isn't. Most of that enormous trophy count happened under one manager who left in 2013, which gets mentioned in pubs and then argued about for an hour. They fill Old Trafford regardless."],
      ["Chelsea", [8.6, 8, 3, 4], "8455-Chelsea.png",
       "Stamford Bridge expects to win. That's the whole culture: big signings, quick sackings, trophies or else. The rest of the league finds this insufferable and says so at length. Stamford Bridge doesn't especially care."],
      ["Tottenham", [7.7, 10, 5, 5], "8586-Tottenham.png",
       "Spurs won a European trophy and nearly went down in the same season, Spursy. That is the life of a Spurs supporter: It'll be brilliant for a while, then it'll fall apart in the most creative way possible. They keep coming back anyway, partly out of loyalty, partly because when it clicks, it's genuinely the best football in London. They'd rather go down in a blaze of glory than watch Conte grind out a 1-0 win."],
      ["Newcastle", [6.3, 8, 1, 10], "10261-Newcastle.png",
       "Ask a Newcastle fan when they last won a major trophy and watch them not care about the answer. St James' Park sits right in the middle of the city and on matchday the whole place is black and white. No silverware for decades, sold out every week anyway. That's not hope so much as habit, and they wouldn't trade it. Just don't ask them about where all that money is coming from."],
      ["Aston Villa", [4.1, 6, 4, 6], "10252-Aston Villa.png",
       "Villa won the European Cup in 1982 and spent forty years being reminded it was a while ago. The Holte End remembers anyway. Now that the club's good again, it feels less like a surprise and more like things going back to normal."],
      ["Brighton", [1.9, 6, 8, 1], "10204-Brighton.png",
       "Thirty years ago Brighton was ground-sharing in Gillingham and nearly went under. Now they sell their best player every summer, buy someone nobody's heard of, and finish higher. They were ground-sharing in Gillingham and nearly went under; now it is a properly run club, and that's rarer than it should be."],
      ["Crystal Palace", [2.7, 5, 7, 5], "9826-Crystal Palace.png",
       "The Holmesdale end at Selhurst is the loudest thing in south London on a derby day. Palace went a century without a major trophy, won the FA Cup in 2025, and South London hasn't shut up since. Fair enough."],
      ["Nott'm Forest", [3.6, 3, 3, 6], "10203-Nottm Forest.png",
       "Two European Cups. Forest fans will get that in within the first minute of any football conversation, and fair enough, because Clough winning back-to-back with Nottingham Forest is still one of the maddest things that's ever happened in the sport. The tricky part is that everything since has to live next to it. The fans don't seem to mind. They know what they've got."],
      ["Everton", [4.1, 2, 5, 8], "8668-Everton.png",
       "The People's Club, and they're not joking. Everton fans have spent years convinced the whole system is against them, and to be fair, the points deductions didn't help the paranoia. Decades of grievance and free-flowing misery, and the crowd wouldn't have had it any other way."],
      ["Fulham", [1.8, 4, 6, 0], "9879-Fulham.png",
       "You walk to Craven Cottage along the river past people having a nice time. Nobody here is going to ruin their weekend over a defeat. It's the least stressful football in London, and there's a decent argument that's the correct way to do it."],
      ["Brentford", [1.4, 5, 8, 2], "9937-Brentford.png",
       "At Brentford, the story is one of innovation—data, grit, and a refusal to follow the old rules. Once the underdog, now a club with its own identity, Brentford has earned respect one result at a time."],
      ["Bournemouth", [1.4, 9, 7, 1], "8678-Bournemouth.png",
       "At Bournemouth, fans know their club is small, and that's part of the charm. There's no weighty history—just the thrill of being part of something growing, one match at a time."],
      ["Sunderland", [1.4, 5, 6, 9], "8472-Sunderland.png",
       "Sunderland spent years in League One playing in front of 30,000 people, which is either magnificent or deranged depending on your view of the north east. The Netflix documentary made the suffering famous; the fans lived it. Things are looking up now, and Wearside is cautiously letting itself believe again. Cautiously."],
      ["Leeds", [4.1, 8, 6, 8], "8463-Leeds.png",
       "Elland Road on a night game is genuinely intimidating, and the fans know it. Leeds spent sixteen years outside the top flight and the crowds barely dipped, which is either loyalty or madness depending on who you ask. Half of Yorkshire seems to support them. The other half hates them, and Leeds fans like it that way."],
      ["Ipswich", [0.5, 7, 8, 5], "9902-Ipswich.png",
       "Portman Road, a quiet part of Suffolk, and the only club anyone there cares about. Went down, came straight back, didn't make much of either. Nobody's chasing headlines, and the fans seem to prefer it like that."],
      ["Coventry", [0.0, 7, 7, 6], "8669-Coventry.png",
       "Coventry City fans have weathered exile, heartbreak, and more. Still, the singing never stopped. For the Sky Blues, it's about loving the club, not chasing silverware."],
      ["Hull", [0.0, 4, 4, 5], "8667-Hull.png",
       "Hull is the club nobody thinks about, which suits the fans fine. It's a long way from everywhere, the glamour ties are rare, and the ownership sagas have tested everyone's patience. People still turn up. There's no bandwagon to jump on at Hull, so everyone in the ground actually means it."],
    ].freeze

    # Upsert the league and its teams. Returns the League.
    def call
      DB.transaction do
        league = upsert_league
        TEAMS.each_with_index { |(name, scores, crest, blurb), i| upsert_team(league, name, scores, crest, blurb, i) }
        league
      end
    end

    def upsert_league
      league = League.first(slug: LEAGUE[:slug]) || League.new(slug: LEAGUE[:slug])
      league.set(name: LEAGUE[:name], season: LEAGUE[:season], active: true, position: 0,
                 chooser_threshold: LEAGUE[:chooser_threshold], max_choices: LEAGUE[:max_choices],
                 amplify: LEAGUE[:amplify])
      league.save
      league
    end

    def upsert_team(league, name, scores, crest, blurb, position)
      vibe, play, ethics, fanbase = scores
      team = Team.first(league_id: league.id, name:) || Team.new(league_id: league.id, name:)
      team.set(vibe:, play:, ethics:, fanbase:, blurb:, crest:, position:)
      team.save
      team
    end
  end
end
