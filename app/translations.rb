# frozen_string_literal: true

require "yaml"

# Hand-rolled, dependency-free i18n for the two locales this app ships (en, fr).
# The stack is deliberately lean (see CLAUDE.md), so this is plain Ruby + a couple
# of YAML files rather than the Rails/i18n gem.
#
# English is the source language: view literals and the quiz content in Ruby
# (Quiz::Data, Quiz::Archetype) stay canonical English, and `en.yml` mirrors the
# UI strings so `t` has an English fallback for every key. `fr.yml` supplies the
# French UI strings plus a `content:` section that overrides the quiz questions,
# sliders and archetype copy. Adding a language = add `<code>.yml` and translate.
#
# Three surfaces read this:
#   - server ERB views, via App#t (dotted keys, %{var} interpolation)
#   - the React client, which is handed the resolved `client` sub-tree as
#     window.QUIZ_I18N (see App#render_quiz)
#   - the quiz content services, via .content(locale) (Quiz::Data / Quiz::Archetype)
module Translations
  module_function

  DEFAULT = "en"
  SUPPORTED = %w[en fr].freeze

  LOCALE_DIR = File.expand_path("../config/locales", __dir__)

  # { "en" => {...}, "fr" => {...} }, loaded once. String keys throughout. Each
  # file namespaces its tree under the locale code (the Rails-i18n convention), so
  # unwrap that top level here.
  def dict
    @dict ||= SUPPORTED.to_h do |code|
      path = File.join(LOCALE_DIR, "#{code}.yml")
      loaded = YAML.safe_load_file(path) || {}
      [code, loaded[code] || {}]
    end
  end

  # Force a reload — used by the test suite when it needs a clean slate.
  def reset!
    @dict = nil
  end

  # Translate a dotted key ("result.share_label") in `locale`, falling back to the
  # English string and finally to the key itself so a missing translation is
  # visible rather than blank. %{var} placeholders are filled from `vars`.
  def t(key, locale: DEFAULT, **vars)
    value = lookup(dict[locale], key)
    value = lookup(dict[DEFAULT], key) if value.nil?
    value = key if value.nil?
    value.is_a?(String) ? interpolate(value, vars) : value
  end

  # The client (React) string tree for a locale, English-merged so a key the
  # translation omits still resolves. Embedded verbatim as window.QUIZ_I18N.
  def client(locale = DEFAULT)
    base = dict[DEFAULT]["client"] || {}
    return base if locale == DEFAULT

    deep_merge(base, dict[locale]["client"] || {})
  end

  # Locale overrides for the quiz CONTENT (questions, sliders, archetypes, axis
  # labels). English is the canonical Ruby source, so it has no overrides — an
  # empty hash means "use the source". Only translated locales carry a section.
  def content(locale = DEFAULT)
    dict[locale]["content"] || {}
  end

  # Pick the locale for a request: an explicit, supported cookie wins; otherwise
  # negotiate the Accept-Language header; otherwise the default. `cookie` is the
  # raw cookie value (may be nil or junk), `header` the raw Accept-Language.
  def resolve(cookie: nil, header: nil)
    return cookie if SUPPORTED.include?(cookie)

    negotiate(header) || DEFAULT
  end

  # Best supported language from an Accept-Language header, honouring q-values,
  # or nil when none match. "fr-CA,fr;q=0.9,en;q=0.8" -> "fr".
  def negotiate(header)
    return nil if header.nil? || header.strip.empty?

    header.split(",")
          .filter_map { |part| parse_language_range(part) }
          .sort_by { |(_, q)| -q }
          .map(&:first)
          .find { |base| SUPPORTED.include?(base) }
  end

  # One "fr-CA;q=0.9" range -> ["fr", 0.9], or nil if it has no tag. The quality
  # defaults to 1.0 and the region subtag is dropped (we match on primary only).
  def parse_language_range(part)
    tag, *params = part.split(";").map(&:strip)
    return if tag.nil? || tag.empty?

    q_param = params.find { |p| p.start_with?("q=") }
    quality = q_param ? q_param.split("=", 2).last.to_f : 1.0
    [tag.downcase.split("-").first, quality]
  end

  # --- internals ---

  def lookup(tree, key)
    key.to_s.split(".").reduce(tree) do |node, segment|
      node.is_a?(Hash) ? node[segment] : nil
    end
  end

  def interpolate(string, vars)
    return string if vars.empty?

    string.gsub(/%\{(\w+)\}/) { vars[Regexp.last_match(1).to_sym]&.to_s || Regexp.last_match(0) }
  end

  # Recursive hash merge; scalars and arrays from `override` replace the base.
  def deep_merge(base, override)
    base.merge(override) do |_key, base_val, over_val|
      base_val.is_a?(Hash) && over_val.is_a?(Hash) ? deep_merge(base_val, over_val) : over_val
    end
  end
end
