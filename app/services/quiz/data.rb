# frozen_string_literal: true

module Quiz
  # The questionnaire and scoring model — league-agnostic. Team scores and blurbs
  # now live in the database (the League/Team models); this holds only the fixed
  # bits shared across every league: the four axes, the questions and their
  # loadings, the weight sliders, and the matching constants.
  #
  # 4-coordinate model per answer/team: [Vibe, Play, Ethics, Fanbase].
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
  end
end
