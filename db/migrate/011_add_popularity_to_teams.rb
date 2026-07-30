# frozen_string_literal: true

# Global popularity weight per club, used by the distribution-aligned scorer
# (Quiz::Score#target_of): the matching target is the league's team cloud weighted
# by popularity**POPULARITY_ALPHA, so more-supported clubs pull the target toward
# themselves. Default 1.0 means "unweighted" — a league with no popularity data
# scores exactly as a plain coordinate distribution, so this is safe to ship
# before every league is curated. Provisional placeholder figures live in the
# seed; replace with a real engagement metric (international supporters' clubs,
# active members) rather than ad-driven reach.
Sequel.migration do
  change do
    add_column :teams, :popularity, Float, null: false, default: 1.0
  end
end
