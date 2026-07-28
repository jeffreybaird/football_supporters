# frozen_string_literal: true

module Quiz
  # Pure recommender maths — no DB access of its own; it is handed the league's
  # teams. Faithful port of the original browser scorer so a shared /q/:slug
  # result matches what the taker saw:
  #
  #   answers (per question: chosen option index or nil)
  #     -> loadings-weighted mean per axis  (score_axes)
  #     -> centrality-amplified, slider-weighted nearest-team ranking (rank_teams)
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
    # chooser_threshold / max_choices / amplify: per-league tuning (see
    #   Quiz::Data); default to the shared constants for callers with no league.
    def call(teams:, answers:, weights:,
             chooser_threshold: Data::CHOOSER_THRESHOLD,
             max_choices: Data::MAX_CHOICES,
             amplify: Data::AMPLIFY)
      vec  = score_axes(answers)
      rank = rank_teams(vec, weights, teams, amplify)
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

    # slider-weighted distance matching (nearest team). The user's vector is first
    # stretched outward from the team centroid (AMPLIFY) so moderate answers stop
    # collapsing onto the centre team.
    def rank_teams(vec, weights, teams, amplify)
      centroid = centroid_of(teams)
      wsum = weights.sum.to_f
      wsum = 1.0 if wsum.zero?
      w = weights.map { |x| x / wsum }
      u = vec.each_index.map do |k|
        a = centroid[k] + ((vec[k] - centroid[k]) * amplify)
        a.clamp(0.0, 10.0)
      end
      ranked = teams.each_with_index.map do |team, idx|
        t = team.vector
        dist = Math.sqrt(w.each_index.sum { |k| w[k] * ((u[k] - t[k])**2) })
        # match% is derived from the RAW user vector (no amplify): amplify is a
        # ranking spread trick and must not distort the human-facing percentage.
        raw = Math.sqrt(w.each_index.sum { |k| w[k] * ((vec[k] - t[k])**2) })
        match = (1.0 - (raw / DIAMETER)).clamp(0.0, 1.0)
        [Ranked.new(team, dist, 1.0 / (1.0 + dist), match), idx]
      end
      ranked.sort_by { |r, idx| [-r.sim, idx] }.map(&:first)
    end

    # per-axis mean of the supplied teams' vectors — the centre of the team cloud
    def centroid_of(teams)
      Data::AXES.each_index.map do |k|
        teams.sum { |team| team.vector[k] } / teams.length.to_f
      end
    end
  end
end
