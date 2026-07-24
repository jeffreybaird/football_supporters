# frozen_string_literal: true

module Quiz
  # Idempotent seed for the shipped leagues and their clubs. This is the *initial
  # content* for the DB-backed League/Team model — the app reads teams from the
  # database, never from here. Run via `rake db:seed`; the test suite runs it
  # once after migrating. Re-running upserts, so it is safe to run repeatedly.
  #
  # Adding another league means adding another entry to LEAGUES (or inserting
  # rows by any other means) — no code changes elsewhere. Scores come from
  # db/team_scores.csv; blurbs/crests are authored here.
  module Seed
    module_function

    # Premier League clubs — name, [vibe, play, ethics, fanbase], crest file, blurb.
    PREMIER_LEAGUE_TEAMS = [
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

    # Bundesliga clubs — same shape.
    BUNDESLIGA_TEAMS = [
      ["Bayern Munich", [10, 6, 4, 5], "9823-Bayern_München.png",
       "FC Hollywood. The nickname is from the nineties but it never really stopped fitting: boardroom feuds, coaching drama, tabloid soap opera, and a title at the end of it anyway. Bayern poach their rivals' best players so routinely that Dortmund fans can list the thefts from memory. The ultras protest ticket prices and sportswashing while the club hoovers up trophies. Everyone else in Germany resents them, and Bayern fans have made peace with that, roughly around title number twenty."],
      ["Borussia Dortmund", [8, 9, 8, 10], "9789-Dortmund.png",
       "The Yellow Wall is 25,000 people standing on one terrace, and Lahm said it eats you up. He wasn't exaggerating much. Dortmund sell the working-class romance hard, “echte Liebe” and cheap standing tickets, and rivals enjoy pointing out the club is a publicly traded company doing all this romance at industrial scale. Fair point. Doesn't make the wall any quieter."],
      ["RB Leipzig", [8, 8, 0, 2], "178475-RB_Leipzig.png",
       "The most hated club in Germany, and it isn't close. A tabloid once refused to print the name and listed them in the table as “Dosenverkauf,” can-sellers. The club has a comically small membership on purpose, which is the whole 50+1 trick. The people who actually go are mostly just Saxons happy to have top football back after decades of nothing, and they've stopped apologizing for it. The rest of the league will never forgive them. Both sides seem fine with the arrangement."],
      ["Bayer Leverkusen", [6, 7, 3, 2], "8178-Leverkusen.png",
       "Neverkusen. Decades of that name, earned the hard way, capped by blowing a treble in 2002. Then Alonso's team went a whole league season unbeaten, the first in Bundesliga history, won the double, and the club started calling itself Neverlusen. Rivals still sneer about the aspirin works team with no real fans. Leverkusen fans used to have nothing to say back. Now they just point at 2024."],
      ["Eintracht Frankfurt", [5, 7, 8, 9], "9810-Frankfurt.png",
       "When Frankfurt played at Camp Nou, about thirty thousand of them got in on a five thousand ticket allocation. Nobody knows exactly how. That's the club: the biggest, rowdiest away following in Europe, pyro everywhere, UEFA charges collected like stickers. The 2022 Europa League win sent the whole city feral. Frankfurt fans don't do quiet seasons, only invasions and crises."],
      ["VfB Stuttgart", [6, 6, 6, 7], "10269-VfB_Stuttgart.png",
       "Stuttgart fans watched their big traditional club get run into the ground twice, relegated twice, and kept showing up sixty thousand at a time. Then came the good part: second place above Bayern in 2024, and the 2025 Pokal, the first real trophy since 2007. The Cannstatter Kurve marches to the ground before every match like it's a ritual, because it is. Swabians don't gush. The full stadium is the gushing."],
      ["Hamburger SV", [5, 6, 5, 9], "9790-Hamburger_SV.png",
       "HSV had a clock in the stadium counting their unbroken decades in the Bundesliga, which became the funniest object in Germany the day they went down. Then seven years in the second division, four fourth-place finishes, playoff heartbreaks, and the special insult of watching St. Pauli go up first. The Volkspark stayed near sixty thousand through all of it. They're back now, promoted under a hometown coach in his mid-thirties, and the pitch invasion looked less like joy than relief."],
      ["Schalke 04", [5, 5, 4, 10], "10189-Schalke_04.png",
       "Schalke drew nearly sixty thousand a game in the second division while flirting with a drop to the third, which tells you everything about the split between the fans and whoever's running the place. The Knappen name comes from the mines, and in Gelsenkirchen that's not branding, it's the actual history of most families in the ground. Champions of the second tier in 2026, back up, and the Revierderby with Dortmund is back with them. German football was noticeably worse without it."],
      ["Werder Bremen", [4, 5, 6, 8], "8697-Werder_Bremen.png",
       "Third in the all-time Bundesliga table, which surprises people who only know the recent lean years. Bremen is a port city with one club and a stadium on the river that stays loud through everything, including the second division. The Ostkurve is proudly political, anti-fascist and unapologetic about it. When the front office botched the transfer window recently, fans had a protest petition to thousands of signatures within hours. They're patient with bad results. Bad stewardship is different."],
      ["Borussia Mönchengladbach", [4, 7, 7, 7], "9788-Mgladbach.png",
       "Gladbach were the coolest team in Europe for about a decade, and that decade ended fifty years ago. The fans know this. Rivals remind them anyway. What's left is one of Germany's biggest fanbases sustaining itself on Netzer stories and the Rheinderby with Köln, which both clubs insist is the only Rhine derby that counts. The Nordkurve deserves a better team than it usually gets. It has for a while."],
      ["1. FC Köln", [4, 7, 7, 9], "8722-Köln.png",
       "The club with a live goat. Hennes IX attends matches, has a better contract situation than most of the squad, and is treated with total seriousness by everyone involved. Köln fans hold services in the cathedral before big European ties and once put twenty thousand people in London for a group stage game. The team gets relegated, comes straight back up, and the Südkurve forgives it all by carnival season. It's less a football club than a citywide condition."],
      ["TSG Hoffenheim", [4, 5, 2, 1], "8226-Hoffenheim.png",
       "A village of three thousand people, one billionaire, and a Bundesliga team the rest of Germany treats as a science experiment. The fixture against Leipzig got nicknamed El Plastico, the battle of the unloved, and it stuck. The strange twist is that Hoffenheim's own ultras have turned on Hopp too, over broken promises about giving the club back to its members. When even your own fans are protesting the owner, the plastic jokes almost stop being the problem."],
      ["SC Freiburg", [3, 4, 9, 5], "8358-Freiburg.png",
       "Nobody hates Freiburg. A commentator who's covered the league for decades said he's never met anyone who does, and that might be the strangest fact in German football. The coach cycled to work for thirteen years. The club buys players nobody scouted and finishes above teams spending triple. They made a Europa League final in 2025 and even that didn't generate any enemies. It should be insufferable. Somehow it isn't."],
      ["Union Berlin", [2, 2, 10, 10], "8149-Union_Berlin.png",
       "Union fans donated blood to fund the club and rebuilt the stadium with their own hands, over two thousand volunteers, six figures of unpaid hours. So when they talk about it being theirs, it's not a metaphor. The Alte Försterei does Christmas carol singalongs and played host to Real Madrid within the same few years, and neither changed anything about the place. Every other club claims authenticity. Union has receipts."],
      ["Mainz 05", [3, 5, 8, 6], "9905-Mainz.png",
       "The Karnevalsverein, and proud of it. Goals at Mainz are followed by an actual carnival march over the PA, and nobody in the ground is under any illusion about winning the league. This is the club that produced Klopp and Tuchel, which fans mention constantly, though when Klopp took the Red Bull job the city put him on a carnival float clutching a can, wings made of banknotes. Mainz forgives most things. Not that."],
      ["FC Augsburg", [1, 3, 5, 5], "8406-Augsburg.png",
       "Every August somebody picks Augsburg to go down, and every May they're still there, having played some of the least memorable football in the division. German media has called them the league's most unspectacular club, and honestly the fans have heard worse. There's no glamour, no famous history, just fifteen straight seasons of survival that better-supported clubs would kill for. Boring is a strategy. It works."],
      ["SV Elversberg", [0, 8, 5, 3], "8232-Elversberg.png",
       "Spiesen-Elversberg has about thirteen thousand residents and now a Bundesliga club, reportedly the smallest town ever to manage it. They lost the promotion playoff in the last minute in 2025, lost their coach and best striker that summer, and came back and scored more goals than anyone in the division anyway. Someone on German TV called them Real Elversberg for the white kits and the passing. A ZDF reporter predicted the stay will be short. Probably right. Nobody in the Saarland cares yet."],
      ["SC Paderborn", [0, 6, 6, 5], "8460-Paderborn.png",
       "Paderborn have finished dead last in the Bundesliga twice, which locals will tell you about themselves before you can. The club motto translates to “heroes never give up,” which sounds like a poster until you watch them win a promotion playoff in the 100th minute against Wolfsburg, sending a club down for the first time in 29 years. Nobody in Paderborn is planning the title parade. They know exactly how this movie usually ends, and they bought tickets anyway."],
    ].freeze

    # Ligue 1 clubs — same shape.
    LIGUE_1_TEAMS = [
      ["Paris Saint-Germain", [10, 7, 0, 4], "9847-PSG.png",
       "For a decade PSG were Europe's most expensive punchline: infinite Qatari money, annual Champions League collapse. Then Mbappé left, Luis Enrique built a team with no superstars, and they beat Inter 5-0 in the 2025 final, the biggest winning margin the competition has ever seen. The rest of France still resents everything about them, and the club president responds by listing the English teams they knocked out. Winning didn't make them loved. It made the hating quieter."],
      ["Marseille", [8, 9, 5, 10], "8592-Marseille.png",
       "The most supported and most hated club in France, usually by the same logic. The Vélodrome is the loudest ground in the country, run by ultra groups older than most of the squad, and OM fans frame the PSG rivalry as class war: the port city against the state project. They have the one thing Qatar couldn't buy for years, the 1993 Champions League, and “à jamais les premiers” is tattooed on the city. Everything at OM is a crisis or a crusade. There is no third setting."],
      ["Monaco", [6, 9, 1, 0], "9829-Monaco.png",
       "A club in a tax haven, owned by a Russian billionaire, playing to four-figure crowds in a principality where most residents could buy the team. Monaco regularly finish top three and once drew under five thousand for a league match, which is the whole joke in one sentence. Rivals resent the tax-free salaries. Nobody resents the fans, because there aren't enough of them to resent."],
      ["Lyon", [6, 6, 4, 6], "9748-Lyon.png",
       "Seven straight titles in the 2000s, and then John Textor nearly killed the club. Administratively relegated over the debt in 2025, saved on appeal by fire-selling players and a change of ownership, all while the Bad Gones watched their giant get run like a distressed asset. Lyon ultras are famous for making players stand and listen after bad defeats. Lately there's been a lot to listen to."],
      ["Lille", [5, 4, 5, 5], "8639-Lille.png",
       "The smartest sellers in world football, literally, per CIES. Lille buy unknowns, win the occasional shock title (2011 with Hazard, 2021 over PSG's billions), and sell everyone at triple the price. It's a cold, well-run machine in a giant modern stadium, and the one day a year the temperature changes is the Derby du Nord against Lens, mining country against the city. Lens took the first leg 3-0 this season. Lille returned it 3-0. That's the relationship."],
      ["Lens", [4, 7, 9, 10], "8588-Lens.png",
       "Bollaert has more seats than Lens has residents and has sold out every game for four years running. Before kickoff, 38,000 people raise scarves for the Lensoise and sing a mining anthem about dead coal towns, and it's the best pre-match ritual in France by a distance. This is the poorest region in the country holding up the league's second-best team. The club just bought its own stadium back. If French football has a soul, it commutes to Bollaert."],
      ["Rennes", [4, 8, 8, 7], "9851-Rennes.png",
       "Owned by the Pinault family, France's third-richest, who genuinely love the club, which makes the trophy count genuinely awkward: one cup, one podium, decades of money. The French press periodically runs “is Pinault cheap?” pieces and the fans periodically run out of patience. The Breton anthem before every home game is non-negotiable. The Roazhon Celtic Kop is anti-modern-football to its core, at a club owned by a luxury goods empire. Nobody said identity was tidy."],
      ["Nice", [3, 4, 3, 5], "9831-Nice.png",
       "Nice fans spent 2025-26 watching Ratcliffe pour everything into Manchester United while their club rotted, and he'd already admitted he didn't watch Nice because they were “too weak.” The coach quit in December, fans confronted players in a car park, two of them went on sick leave, and survival came down to winning a playoff. There's a petition demanding INEOS leave. It's not subtle, and it's not wrong."],
      ["Strasbourg", [3, 8, 1, 7], "9848-Strasbourg.png",
       "The team is young and good and the fans are furious anyway, because Chelsea's owners bought the club and treat it like a farm. The ultras went silent for the first fifteen minutes of every home game all season in protest. Then Chelsea signed Strasbourg's captain, then took their coach mid-season, and Strasbourg fans traveled to Stamford Bridge to protest next to Chelsea fans, who agreed with them. Winning while owned this way just makes it more complicated."],
      ["Paris FC", [3, 6, 2, 1], "6379-Paris_FC.png",
       "The other Paris club, ignored for fifty years, now owned by the Arnault family with Red Bull holding a slice and Klopp advising. That sentence is why half of France rolled its eyes at the promotion. There's no organic fanbase yet, the ground has no atmosphere by Klopp's own admission, and the whole thing reads as a luxury conglomerate manufacturing a rival to PSG. It might work. It will not be loved while it does."],
      ["Toulouse", [2, 5, 3, 4], "9941-Toulouse.png",
       "RedBird's quiet data project in rugby country. Toulouse won a Coupe de France in 2023 playing Moneyball, which fans enjoyed, and have since drifted through competent mid-table seasons while the American fund says nothing publicly, which fans enjoy less. The Indians Tolosa put out a statement literally asking the owners to speak. In a league full of ownership disasters, silence is a mild complaint. It still stings."],
      ["Brest", [2, 6, 8, 5], "8521-Brest.png",
       "Brest finished third in 2024 and reached the Champions League with a stadium so old it failed UEFA's rules, so they played European “home” games a hundred kilometers away in Guingamp. Three of the stands sit on scaffolding. The president called the whole thing unimaginable and meant it. There's no money, no plan for empire, just a small Breton port club that briefly gatecrashed the biggest competition on earth. Everyone's second team, and they've earned it."],
      ["Auxerre", [2, 3, 7, 5], "8583-Auxerre.png",
       "A town of thirty-nine thousand, and one man managed the club for forty-four years. Guy Roux took Auxerre from the fifth tier to the 1996 title, produced Cantona along the way, and still turns up at the Abbé-Deschamps at 87. No club in France has an identity this completely tied to one person. Everything since has been an epilogue, and the fans seem at peace with that. Some clubs have history. Auxerre has a biography."],
      ["Angers", [1, 2, 2, 3], "8121-Angers.png",
       "On the pitch, Angers are the likeable survivor: small budget, good academy, somehow still up. Off it, the story is uglier — the longtime owner was convicted of sexually assaulting six employees and handed the club to his son. The fans didn't choose any of that, and the team keeps grinding out safety while the ownership question hangs over the place. Plucky is the brand. It's complicated underneath."],
      ["Le Havre", [1, 2, 8, 7], "9746-Le_Havre.png",
       "The oldest club in France, founded by the English in 1872, with a chant set to God Save the King to prove it: forever the first of all French clubs. It's a working port city that was flattened in 1944 and rebuilt, and the club carries itself the same way. Most seasons are a survival scrap. The fans hold the seniority card over everyone, including PSG, and play it constantly. When you've been around 150 years, staying up is the tradition."],
      ["Lorient", [1, 6, 4, 5], "8689-Lorient.png",
       "The hake, from the fishing port, and the league's most reliable elevator: down in 2024, straight back up, comfortably mid-table. Lorient's inheritance is Gourcuff's one-touch passing game, which once got them called the Arsenal of Ligue 1, back when that was a compliment. Bournemouth's owner bought the club outright in January, so the multi-club era has arrived here too. The fans will take the yo-yo. It beats the alternative both directions."],
      ["Troyes", [1, 5, 1, 2], "10242-Troyes.png",
       "City Football Group's tenth club, which is the least romantic sentence in French football. Troyes yo-yo between divisions as Manchester City's development shelf, nearly fell to the third tier two years ago, and just won Ligue 2 anyway. French ultras despise the feeder model on principle, and Troyes fans are stuck supporting a club whose transfer decisions get made in a portfolio review. The promotion was real, though. Even a laboratory gets a parade."],
      ["Le Mans", [0, 5, 6, 3], "8682-Le_Mans.png",
       "Liquidated in 2013, dropped to the sixth division, back in Ligue 1 for the first time since 2010. The stadium sits inside the 24 Hours circuit, which is the best pub fact in the league. Promotion was confirmed after their final match got abandoned for crowd trouble and the league upheld the score, which is a very Ligue 2 way to go up. Nobody outside the Sarthe saw them coming. That's the whole appeal."],
    ].freeze

    # Every shipped league: its metadata plus its clubs, in display order. The
    # first entry (position 0) is the app's default league. chooser_threshold /
    # max_choices / amplify override the Quiz::Data defaults per league.
    LEAGUES = [
      { slug: "premier-league", name: "Premier League", season: "2026-27", teams: PREMIER_LEAGUE_TEAMS, amplify: 2.5 },
      { slug: "bundesliga",     name: "Bundesliga",     season: "2026-27", teams: BUNDESLIGA_TEAMS,     amplify: 1.4 },
      { slug: "ligue-1",        name: "Ligue 1",        season: "2026-27", teams: LIGUE_1_TEAMS,        amplify: 1.7, chooser_threshold: 0.25 },
    ].freeze

    # Upsert every league and its teams. Returns the Array of Leagues.
    def call
      DB.transaction do
        LEAGUES.each_with_index.map { |meta, position| upsert_league(meta, position) }
      end
    end

    def upsert_league(meta, position)
      league = League.first(slug: meta[:slug]) || League.new(slug: meta[:slug])
      league.set(name: meta[:name], season: meta[:season], active: true, position:,
                 chooser_threshold: meta.fetch(:chooser_threshold, Data::CHOOSER_THRESHOLD),
                 max_choices: meta.fetch(:max_choices, Data::MAX_CHOICES),
                 amplify: meta.fetch(:amplify, Data::AMPLIFY))
      league.save
      # Crests live under public/images/<league-slug>/; the team arrays carry the
      # bare filename, so qualify it with the league dir before storing.
      meta[:teams].each_with_index do |(name, scores, crest, blurb), i|
        upsert_team(league, name, scores, crest && File.join(meta[:slug], crest), blurb, i)
      end
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
