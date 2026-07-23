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
  module Score
    module_function

    Ranked = Struct.new(:team, :dist, :sim) do
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

    # loadings-weighted mean per axis; axes with no evidence default to 5.0
    def score_axes(answers)
      num = [0.0, 0.0, 0.0, 0.0]
      den = [0.0, 0.0, 0.0, 0.0]
      answers.each_with_index do |oi, q_idx|
        next if oi.nil?

        q = Data::Q[q_idx]
        opt = q["a"][oi]
        4.times do |k|
          load_k = q["load"][k]
          val = opt["v"][k]
          if load_k > 0 && !val.nil?
            num[k] += load_k * val
            den[k] += load_k
          end
        end
      end
      num.each_index.map { |k| den[k] > 0 ? num[k] / den[k] : 5.0 }
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
        a = centroid[k] + (vec[k] - centroid[k]) * amplify
        [[a, 0.0].max, 10.0].min
      end
      teams.each_with_index.map do |team, idx|
        t = team.vector
        dist = Math.sqrt(w.each_index.sum { |k| w[k] * (u[k] - t[k])**2 })
        [Ranked.new(team, dist, 1.0 / (1.0 + dist)), idx]
      end.sort_by { |r, idx| [-r.sim, idx] }.map(&:first)
    end

    # per-axis mean of the supplied teams' vectors — the centre of the team cloud
    def centroid_of(teams)
      Data::AXES.each_index.map do |k|
        teams.sum { |team| team.vector[k] } / teams.length.to_f
      end
    end
  end
end
