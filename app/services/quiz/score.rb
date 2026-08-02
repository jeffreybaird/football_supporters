# frozen_string_literal: true

module Quiz
  # Pure recommender maths — no DB access of its own; it is handed the league's
  # teams. Faithful port of the original browser scorer so a shared /q/:slug
  # result matches what the taker saw:
  #
  #   answers (per question: chosen option index or nil)
  #     -> loadings-weighted mean per axis  (score_axes)
  #     -> distribution-aligned, slider-weighted nearest-team ranking (rank_teams)
  #     -> conditional top-N chooser
  #
  # Similarity is 1/(1+distance) so higher = better; ties break by the team's
  # position in the supplied list, matching the browser's stable sort.
  #
  # `sim` (1/(1+dist)) drives ranking and is intentionally steep, so it is a poor
  # human-facing "% match". The displayed `match` is a separate, gentler number:
  # the RAW (pre-amplify) weighted distance mapped linearly across the space
  # diameter — see DIAMETER and #rank_teams.
  module Score
    module_function

    # Axes span 0..10 and the normalized weights sum to 1, so the largest possible
    # weighted distance is sqrt(sum(w) * 10**2) = 10. `match` maps a team's raw
    # distance linearly across this diameter: match = 1 - raw_dist/DIAMETER.
    DIAMETER = 10.0

    Ranked = Struct.new(:team, :dist, :sim, :match) do
      def name = team.name
    end
    Result = Struct.new(:vec, :rank, :candidates, :pick, :gap, keyword_init: true)

    # teams:   ordered Array of Team (a league's kept teams).
    # answers: Array(len Q) of chosen option index or nil.
    # weights: Array(4) of slider values.
    # chooser_threshold / max_choices: per-league tuning (see Quiz::Data).
    # alpha: popularity-trust dial for the matching target (see Quiz::Data);
    #   defaults to the shared constant.
    def call(teams:, answers:, weights:,
             chooser_threshold: Data::CHOOSER_THRESHOLD,
             max_choices: Data::MAX_CHOICES,
             alpha: Data::POPULARITY_ALPHA)
      rank_vector(vec: score_axes(answers), teams:, weights:, chooser_threshold:, max_choices:, alpha:)
    end

    # Rank a KNOWN axis vector against a league's teams — the shared core of #call
    # and the entry point for callers that already hold a vector rather than the 13
    # answers (e.g. an LLM inferring a supporter vector from conversation). Returns
    # the same Result as #call; #call is just this with score_axes in front.
    def rank_vector(vec:, teams:, weights:,
                    chooser_threshold: Data::CHOOSER_THRESHOLD,
                    max_choices: Data::MAX_CHOICES,
                    alpha: Data::POPULARITY_ALPHA)
      rank = rank_teams(vec, weights, teams, alpha)
      candidates = rank.each_with_index
                       .select { |r, i| i.zero? || (r.dist - rank[0].dist) < chooser_threshold }
                       .first(max_choices)
                       .map { |r, _i| r.team }
      gap = rank.length > 1 ? rank[1].dist - rank[0].dist : 0.0
      Result.new(vec:, rank:, candidates:, pick: rank[0].team, gap:)
    end

    # loadings-weighted mean per axis; axes with no evidence default to 5.0.
    # answers is the stored id->option map ({ "V2" => 1, ... }); a legacy
    # positional array is normalized to that shape first (answers_by_id) so old
    # rows still score identically.
    def score_axes(answers)
      by_id = answers_by_id(answers)
      num = [0.0, 0.0, 0.0, 0.0]
      den = [0.0, 0.0, 0.0, 0.0]
      Data::Q.each do |q|
        oi = by_id[q["id"]]
        next if oi.nil?

        opt = q["a"][oi]
        4.times do |k|
          load_k = q["load"][k]
          val = opt["v"][k]
          if load_k.positive? && !val.nil?
            num[k] += load_k * val
            den[k] += load_k
          end
        end
      end
      num.each_index.map { |k| den[k].positive? ? num[k] / den[k] : 5.0 }
    end

    # Normalize stored answers to a { question_id => option_index } map. A Hash is
    # already in that shape; a legacy positional array is aligned to Data::Q order.
    def answers_by_id(answers)
      return answers if answers.is_a?(Hash)

      Data::Q.each_index.to_h { |i| [Data::Q[i]["id"], answers[i]] }
    end

    # slider-weighted distance matching (nearest team). The user's answer vector is
    # first distribution-aligned (see Quiz::Data): each axis is standardised against
    # the USER population and re-placed in the TARGET distribution — the league's
    # team cloud weighted by popularity**alpha. This de-biases the self-report and
    # matches each axis's spread, and it is what makes popular clubs reachable.
    def rank_teams(vec, weights, teams, alpha)
      target = target_of(teams, alpha)
      wsum = weights.sum.to_f
      wsum = 1.0 if wsum.zero?
      w = weights.map { |x| x / wsum }
      u = vec.each_index.map { |k| aligned(vec[k], k, target).clamp(0.0, 10.0) }
      ranked = teams.each_with_index.map do |team, idx|
        t = team.vector
        dist = Math.sqrt(w.each_index.sum { |k| w[k] * ((u[k] - t[k])**2) })
        # match% is derived from the RAW user vector (no alignment): alignment is a
        # ranking device and must not distort the human-facing percentage.
        raw = Math.sqrt(w.each_index.sum { |k| w[k] * ((vec[k] - t[k])**2) })
        match = (1.0 - (raw / DIAMETER)).clamp(0.0, 1.0)
        [Ranked.new(team, dist, 1.0 / (1.0 + dist), match), idx]
      end
      ranked.sort_by { |r, idx| [-r.sim, idx] }.map(&:first)
    end

    # Standardise one axis of the user vector against the USER population, then
    # re-place it in the target distribution:
    #   target_mean + (value - user_mean) * (target_sd / user_sd).
    # A zero user_sd (degenerate axis) falls back to no rescale.
    def aligned(value, axis, target)
      user_sd = Data::USER_SD[axis]
      ratio = user_sd.zero? ? 1.0 : (target[:sd][axis] / user_sd)
      target[:mean][axis] + ((value - Data::USER_MEAN[axis]) * ratio)
    end

    # The matching target: the popularity-weighted mean and sd of the teams'
    # vectors, per axis. Weight is popularity**alpha, so alpha=0 is the plain
    # (unweighted) coordinate distribution and larger alpha leans toward popular
    # clubs. Kept public and mirrored by targetOf in views/quiz/index.erb.
    def target_of(teams, alpha)
      pw = teams.map { |team| (team.popularity || 1.0)**alpha }
      wsum = pw.sum.to_f
      wsum = 1.0 if wsum.zero?
      mean = Data::AXES.each_index.map do |k|
        teams.each_index.sum { |i| pw[i] * teams[i].vector[k] } / wsum
      end
      sd = Data::AXES.each_index.map do |k|
        var = teams.each_index.sum { |i| pw[i] * ((teams[i].vector[k] - mean[k])**2) } / wsum
        Math.sqrt(var)
      end
      { mean:, sd: }
    end
  end
end
