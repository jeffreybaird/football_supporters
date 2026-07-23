# frozen_string_literal: true

module Quiz
  # Single source of truth for the recommender's static dataset (2026-27 season).
  # The Ruby scorer (Quiz::Score) reads these structures directly; the browser
  # quiz reads the very same data as JSON via Quiz::Data.as_json, so the client
  # and server can never drift. String keys throughout so the JSON shape matches
  # what the React app expects verbatim.
  #
  # 4-coordinate model per team/answer: [Vibe, Play, Ethics, Fanbase].
  module Data
    module_function

    AXES = %w[Vibe Play Ethics Fanbase].freeze

    # max weighted-distance gap from the winner for an alternate to be offered
    CHOOSER_THRESHOLD = 0.25
    MAX_CHOICES = 3
    # user-vector centrality amplification: stretch the user's vector outward from
    # the team centroid before matching so moderate answers stop collapsing onto
    # the centre team. 1 = off.
    AMPLIFY = 2.5

    TEAMS = {
      "Man City"       => [10.0, 5, 2, 3],
      "Liverpool"      => [9.6, 9, 6, 7],
      "Arsenal"        => [10.0, 5, 5, 3],
      "Man United"     => [10.0, 6, 4, 8],
      "Chelsea"        => [8.6, 8, 3, 4],
      "Tottenham"      => [7.7, 10, 5, 5],
      "Newcastle"      => [6.3, 8, 1, 10],
      "Aston Villa"    => [4.1, 6, 4, 6],
      "Brighton"       => [1.9, 6, 8, 1],
      "Crystal Palace" => [2.7, 5, 7, 5],
      "Nott'm Forest"  => [3.6, 3, 3, 6],
      "Everton"        => [4.1, 2, 5, 8],
      "Fulham"         => [1.8, 4, 6, 0],
      "Brentford"      => [1.4, 5, 8, 2],
      "Bournemouth"    => [1.4, 9, 7, 1],
      "Sunderland"     => [1.4, 5, 6, 9],
      "Leeds"          => [4.1, 8, 6, 8],
      "Ipswich"        => [0.5, 7, 8, 5],
      "Coventry"       => [0.0, 7, 7, 6],
      "Hull"           => [0.0, 4, 4, 5],
    }.freeze

    TEAM_NAMES = TEAMS.keys.freeze

    Q = [
      { "id" => "V2", "t" => "A game's on with no team of yours involved. You want", "load" => [0.9, 0.5, 0, 0.0], "a" => [
        { "l" => "the better team to win comfortably", "v" => [10, 4, nil, nil] },
        { "l" => "a close, exciting game either way", "v" => [5, 9, nil, nil] },
        { "l" => "the weaker team to cause an upset", "v" => [1, 6, nil, nil] },
        { "l" => "I only watch the teams I support", "v" => [4, 3, nil, nil] },
      ] },
      { "id" => "V4", "t" => "Something you love has a great year. When it's going well, you", "load" => [0.1, 0, 0, 0.8], "a" => [
        { "l" => "make sure people know about it", "v" => [10, nil, nil, 2] },
        { "l" => "enjoy it privately", "v" => [5, nil, nil, 5] },
        { "l" => "celebrate with other fans of my team", "v" => [5, nil, nil, 8] },
        { "l" => "dislike being the one everyone wants to beat", "v" => [0, nil, nil, 4] },
      ] },
      { "id" => "V10", "t" => "Someone is clearly wrong in a comment section. You", "load" => [0.25, 0, 0, 0.6], "a" => [
        { "l" => "reply and argue it out", "v" => [10, nil, nil, 3] },
        { "l" => "write the perfect response in your head but don't post", "v" => [5, nil, nil, 4] },
        { "l" => "scroll past it", "v" => [3, nil, nil, 5] },
        { "l" => "follow the internet's golden rule, never read the comments", "v" => [2, nil, nil, 8] },
      ] },
      { "id" => "P1", "t" => "Your ideal way to win", "load" => [0.1, 0.9, 0, 0], "a" => [
        { "l" => "in control the whole way, 2-0", "v" => [6, 3, nil, nil] },
        { "l" => "a wild high-scoring game, 4-2", "v" => [5, 10, nil, nil] },
        { "l" => "defending a narrow lead, 1-0", "v" => [3, 2, nil, nil] },
        { "l" => "a chaotic game that ends in a draw with a last-minute equaliser", "v" => [4, 6, nil, nil] },
      ] },
      { "id" => "P3", "t" => "Away from sport, how you tend to operate", "load" => [0, 0.7, 0, 0], "a" => [
        { "l" => "work to a clear plan", "v" => [nil, 5, nil, nil] },
        { "l" => "keep a loose framework and adapt", "v" => [nil, 7, nil, nil] },
        { "l" => "go on instinct", "v" => [nil, 9, nil, nil] },
        { "l" => "deal with things as they come", "v" => [nil, 6, nil, nil] },
      ] },
      { "id" => "P5", "t" => "The kind of person you'd want in charge", "load" => [0.2, 0.8, 0, 0.15], "a" => [
        { "l" => "meticulous, has drilled every detail", "v" => [6, 6, nil, 4] },
        { "l" => "an idealist who wants to do it well", "v" => [5, 7, nil, 3] },
        { "l" => "a pragmatist focused on results", "v" => [4, 3, nil, 7] },
        { "l" => "a motivator who lets people off the leash", "v" => [5, 10, nil, 5] },
      ] },
      { "id" => "P8", "t" => "You'd rather watch a team that", "load" => [0, 0.8, 0, 0.0], "a" => [
        { "l" => "controls the game and grinds it out", "v" => [nil, 5, nil, nil] },
        { "l" => "attacks relentlessly and takes risks", "v" => [nil, 10, nil, nil] },
        { "l" => "defends deep and counters", "v" => [nil, 2, nil, nil] },
        { "l" => "competes hard regardless of style", "v" => [nil, 8, nil, nil] },
      ] },
      { "id" => "E5", "t" => "A country with a poor human-rights record hosts a major global event. You", "load" => [0.2, 0, 0.8, 0], "a" => [
        { "l" => "refuse to watch it", "v" => [2, nil, 10, nil] },
        { "l" => "watch, but it sits badly with you", "v" => [5, nil, 6, nil] },
        { "l" => "watch and keep sport and politics separate", "v" => [6, nil, 2, nil] },
        { "l" => "enjoy it, the event is what matters", "v" => [8, nil, 1, nil] },
      ] },
      { "id" => "E6", "t" => "A brand you're loyal to is bought by a corporation that behaves in a way you ethically disagree with. You", "load" => [0, 0, 0.9, 0.15], "a" => [
        { "l" => "stop using it", "v" => [nil, nil, 10, 7] },
        { "l" => "keep using it, but it bothers you", "v" => [nil, nil, 6, 6] },
        { "l" => "carry on, it doesn't really affect you", "v" => [nil, nil, 2, 4] },
        { "l" => "don't mind, the backing means a better product", "v" => [nil, nil, 1, 3] },
      ] },
      { "id" => "F3", "t" => "The type of city or town you'd prefer to live", "load" => [0.4, 0, 0, 0.8], "a" => [
        { "l" => "my hometown", "v" => [2, nil, nil, 10] },
        { "l" => "somewhere unpretentious with character", "v" => [3, nil, nil, 8] },
        { "l" => "a big city with everything available", "v" => [9, nil, nil, 3] },
        { "l" => "wherever the best opportunities are", "v" => [7, nil, nil, 2] },
      ] },
      { "id" => "F4", "t" => "How do you engage with the fandoms you're part of?", "load" => [0, 0, 0, 0.9], "a" => [
        { "l" => "All in — I follow everything and I'm part of the community", "v" => [nil, nil, nil, 10] },
        { "l" => "I consume all of it, but from home", "v" => [nil, nil, nil, 7] },
        { "l" => "I follow it casually", "v" => [nil, nil, nil, 4] },
        { "l" => "I only show up for the big moments", "v" => [nil, nil, nil, 1] },
      ] },
      { "id" => "F5", "t" => "The crowd you'd rather be part of", "load" => [0.3, 0, 0, 0.8], "a" => [
        { "l" => "loud and intense", "v" => [3, nil, nil, 10] },
        { "l" => "passionate but well-behaved", "v" => [4, nil, nil, 6] },
        { "l" => "relaxed and comfortable", "v" => [5, nil, nil, 3] },
        { "l" => "quiet, with good facilities", "v" => [9, nil, nil, 1] },
      ] },
      { "id" => "F7", "t" => "The kind of place you'd choose to live", "load" => [0.4, 0, 0, 0.8], "a" => [
        { "l" => "close-knit, families there for generations", "v" => [2, nil, nil, 10] },
        { "l" => "mixed and up-and-coming", "v" => [6, nil, nil, 5] },
        { "l" => "newly built and convenient", "v" => [7, nil, nil, 3] },
        { "l" => "the most desirable area you can afford", "v" => [9, nil, nil, 1] },
      ] },
    ].freeze

    SLIDERS = [
      { "ax" => "Vibe",    "q" => "How much does the club's size and status matter?",             "lo" => "Doesn't matter", "hi" => "Matters a lot" },
      { "ax" => "Play",    "q" => "How much does the style of football matter?",                   "lo" => "Doesn't matter", "hi" => "Matters a lot" },
      { "ax" => "Ethics",  "q" => "How much does who owns the club, and how they behave, matter?", "lo" => "Doesn't matter", "hi" => "Matters a lot" },
      { "ax" => "Fanbase", "q" => "How much does fitting in with the fanbase matter?",             "lo" => "Doesn't matter", "hi" => "Matters a lot" },
    ].freeze

    FLAVOR = {
      "Man City" => "Crowded beneath their blue banners, the voices of Manchester City fans echo through The Etihad. The lean years are a distant memory, and their newer fans don't remember them. Their team has been transformed by Abu Dhabi money and is unrecognizable compared to its fallow history. Some call it sports washing, others, glory-hunting. For City supporters, it's loyalty rewarded, no matter what outsiders say.",
      "Chelsea" => "Stamford Bridge expects to win. That's the whole culture: big signings, quick sackings, trophies or else. The rest of the league finds this insufferable and says so at length. Stamford Bridge doesn't especially care.",
      "Newcastle" => "Ask a Newcastle fan when they last won a major trophy and watch them not care about the answer. St James' Park sits right in the middle of the city and on matchday the whole place is black and white. No silverware for decades, sold out every week anyway. That's not hope so much as habit, and they wouldn't trade it. Just don't ask them about where all that money is coming from.",
      "Man United" => "Every August, United fans decide this is the year. It usually isn't. Most of that enormous trophy count happened under one manager who left in 2013, which gets mentioned in pubs and then argued about for an hour. They fill Old Trafford regardless.",
      "Arsenal" => "Arsenal fans spent years getting laughed at for “banter era” collapses, so the title means more than the trophy itself. It's vindication. Of course, being Arsenal fans, they've already moved on to arguing about it online. Every dropped point still gets a fifteen-minute video essay by Tuesday.",
      "Liverpool" => "Every fanbase claims their atmosphere is special. At Anfield it's occasionally, annoyingly, true. The European nights are the thing: Kop in full voice, some doomed away side conceding twice in five minutes. Rival fans find the whole “This Means More” act insufferable, and Liverpool fans know that, and don't care. The self-mythologizing is part of the club. So is the fact that, every so often, the myth actually delivers. When you support Liverpool, You'll Never Walk Alone.",
      "Tottenham" => "Spurs won a European trophy and nearly went down in the same season, Spursy. That is the life of a Spurs supporter: It'll be brilliant for a while, then it'll fall apart in the most creative way possible. They keep coming back anyway, partly out of loyalty, partly because when it clicks, it's genuinely the best football in London. They'd rather go down in a blaze of glory than watch Conte grind out a 1-0 win.",
      "Aston Villa" => "Villa won the European Cup in 1982 and spent forty years being reminded it was a while ago. The Holte End remembers anyway. Now that the club's good again, it feels less like a surprise and more like things going back to normal.",
      "Everton" => "The People's Club, and they're not joking. Everton fans have spent years convinced the whole system is against them, and to be fair, the points deductions didn't help the paranoia. Decades of grievance and free-flowing misery, and the crowd wouldn't have had it any other way.",
      "Crystal Palace" => "The Holmesdale end at Selhurst is the loudest thing in south London on a derby day. Palace went a century without a major trophy, won the FA Cup in 2025, and South London hasn't shut up since. Fair enough.",
      "Fulham" => "You walk to Craven Cottage along the river past people having a nice time. Nobody here is going to ruin their weekend over a defeat. It's the least stressful football in London, and there's a decent argument that's the correct way to do it.",
      "Brighton" => "Thirty years ago Brighton was ground-sharing in Gillingham and nearly went under. Now they sell their best player every summer, buy someone nobody's heard of, and finish higher. They were ground-sharing in Gillingham and nearly went under; now it is a properly run club, and that's rarer than it should be.",
      "Nott'm Forest" => "Two European Cups. Forest fans will get that in within the first minute of any football conversation, and fair enough, because Clough winning back-to-back with Nottingham Forest is still one of the maddest things that's ever happened in the sport. The tricky part is that everything since has to live next to it. The fans don't seem to mind. They know what they've got.",
      "Bournemouth" => "At Bournemouth, fans know their club is small, and that's part of the charm. There's no weighty history—just the thrill of being part of something growing, one match at a time.",
      "Leeds" => "Elland Road on a night game is genuinely intimidating, and the fans know it. Leeds spent sixteen years outside the top flight and the crowds barely dipped, which is either loyalty or madness depending on who you ask. Half of Yorkshire seems to support them. The other half hates them, and Leeds fans like it that way.",
      "Brentford" => "At Brentford, the story is one of innovation—data, grit, and a refusal to follow the old rules. Once the underdog, now a club with its own identity, Brentford has earned respect one result at a time.",
      "Sunderland" => "Sunderland spent years in League One playing in front of 30,000 people, which is either magnificent or deranged depending on your view of the north east. The Netflix documentary made the suffering famous; the fans lived it. Things are looking up now, and Wearside is cautiously letting itself believe again. Cautiously.",
      "Ipswich" => "Portman Road, a quiet part of Suffolk, and the only club anyone there cares about. Went down, came straight back, didn't make much of either. Nobody's chasing headlines, and the fans seem to prefer it like that.",
      "Coventry" => "Coventry City fans have weathered exile, heartbreak, and more. Still, the singing never stopped. For the Sky Blues, it's about loving the club, not chasing silverware.",
      "Hull" => "Hull is the club nobody thinks about, which suits the fans fine. It's a long way from everywhere, the glamour ties are rare, and the ownership sagas have tested everyone's patience. People still turn up. There's no bandwagon to jump on at Hull, so everyone in the ground actually means it.",
    }.freeze

    # team name -> crest file in public/images/ (view falls back to initials if missing)
    BADGE = {
      "Man City"       => "8456-Man City.png",
      "Liverpool"      => "8650-Liverpool.png",
      "Arsenal"        => "9825-Arsenal.png",
      "Man United"     => "10260-Man United.png",
      "Chelsea"        => "8455-Chelsea.png",
      "Tottenham"      => "8586-Tottenham.png",
      "Newcastle"      => "10261-Newcastle.png",
      "Aston Villa"    => "10252-Aston Villa.png",
      "Brighton"       => "10204-Brighton.png",
      "Crystal Palace" => "9826-Crystal Palace.png",
      "Nott'm Forest"  => "10203-Nottm Forest.png",
      "Everton"        => "8668-Everton.png",
      "Fulham"         => "9879-Fulham.png",
      "Brentford"      => "9937-Brentford.png",
      "Bournemouth"    => "8678-Bournemouth.png",
      "Sunderland"     => "8472-Sunderland.png",
      "Leeds"          => "8463-Leeds.png",
      "Ipswich"        => "9902-Ipswich.png",
      "Coventry"       => "8669-Coventry.png",
      "Hull"           => "8667-Hull.png",
    }.freeze

    # per-axis mean of every team vector — the centre of the team cloud
    CENTROID = AXES.each_index.map do |k|
      TEAMS.values.sum { |vec| vec[k] } / TEAMS.length.to_f
    end.freeze

    # The exact payload the browser quiz consumes, so client and server share one
    # dataset. Shape mirrors the original standalone app's literals.
    def as_json
      {
        "AXES"              => AXES,
        "TEAMS"             => TEAMS,
        "Q"                 => Q,
        "SLIDERS"           => SLIDERS,
        "FLAVOR"            => FLAVOR,
        "BADGE"             => BADGE,
        "CHOOSER_THRESHOLD" => CHOOSER_THRESHOLD,
        "MAX_CHOICES"       => MAX_CHOICES,
        "AMPLIFY"           => AMPLIFY,
      }
    end
  end
end
