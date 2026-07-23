# frozen_string_literal: true

module Quiz
  # Pure recommender maths — no DB, no side effects. Faithful Ruby port of the
  # original browser scorer so a shared /q/:slug result matches what the taker saw:
  #
  #   answers (per question: chosen option index or nil)
  #     -> loadings-weighted mean per axis  (score_axes)
  #     -> centrality-amplified, slider-weighted nearest-team ranking (rank_teams)
  #     -> conditional top-N chooser
  #
  # Similarity is 1/(1+distance) so higher = better; ties break by the team's
  # position in Data::TEAM_NAMES, matching the browser's stable sort.
  module Score
    module_function

    Ranked = Struct.new(:name, :dist, :sim)
    Result = Struct.new(:vec, :rank, :candidates, :pick, :gap, keyword_init: true)

    # answers: Array(len Q) of chosen option index or nil.
    # weights: Array(4) of slider values.
    def call(answers:, weights:)
      vec  = score_axes(answers)
      rank = rank_teams(vec, weights)
      candidates = rank.each_with_index
                       .select { |r, i| i.zero? || (r.dist - rank[0].dist) < Data::CHOOSER_THRESHOLD }
                       .first(Data::MAX_CHOICES)
                       .map { |r, _i| r.name }
      gap = rank.length > 1 ? rank[1].dist - rank[0].dist : 0.0
      Result.new(vec:, rank:, candidates:, pick: rank[0].name, gap:)
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
    def rank_teams(vec, weights)
      wsum = weights.sum.to_f
      wsum = 1.0 if wsum.zero?
      w = weights.map { |x| x / wsum }
      u = vec.each_index.map do |k|
        a = Data::CENTROID[k] + (vec[k] - Data::CENTROID[k]) * Data::AMPLIFY
        [[a, 0.0].max, 10.0].min
      end
      Data::TEAM_NAMES.each_with_index.map do |name, idx|
        t = Data::TEAMS[name]
        dist = Math.sqrt(w.each_index.sum { |k| w[k] * (u[k] - t[k])**2 })
        [Ranked.new(name, dist, 1.0 / (1.0 + dist)), idx]
      end.sort_by { |r, idx| [-r.sim, idx] }.map(&:first)
    end
  end
end
