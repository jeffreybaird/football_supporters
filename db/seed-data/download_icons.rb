# frozen_string_literal: true

# Downloads crest images listed in team_logos.csv (Team Name, Logo URL)
# and saves them to public/images/#{LEAGUE_SLUG}/<fotmob-id>-<Team Name>.png, matching the
# crest filename convention used by app/services/quiz/seed.rb for the other leagues.
#
# Usage: ruby db/seed-data/download_icons.rb

require "csv"
require "net/http"
require "uri"
require "fileutils"

LEAGUE_SLUG = "wsl"

CSV_PATH = File.join(__dir__, "#{LEAGUE_SLUG}/team_logos.csv")
OUTPUT_DIR = File.expand_path("../../public/images/#{LEAGUE_SLUG}", __dir__)
MAX_REDIRECTS = 5

def fetch(uri, redirects_left = MAX_REDIRECTS)
  raise "too many redirects for #{uri}" if redirects_left.zero?

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
    http.get(uri.request_uri, "User-Agent" => "football_supporters icon downloader")
  end

  case response
  when Net::HTTPSuccess
    response.body
  when Net::HTTPRedirection
    fetch(URI.join(uri, response["location"]), redirects_left - 1)
  else
    raise "HTTP #{response.code} for #{uri}"
  end
end

FileUtils.mkdir_p(OUTPUT_DIR)

rows = CSV.read(CSV_PATH, headers: true)
failures = []

rows.each do |row|
  name = row["Team Name"]
  url = row["Logo URL"]

  id = url[%r{/(\d+)\.png\z}, 1]
  unless id
    failures << [name, url, "could not parse team id from URL"]
    next
  end

  destination = File.join(OUTPUT_DIR, "#{id}-#{name}.png")

  begin
    File.binwrite(destination, fetch(URI.parse(url)))
    puts "OK   #{name} -> #{destination}"
  rescue StandardError => e
    failures << [name, url, e.message]
    puts "FAIL #{name}: #{e.message}"
  end
end

if failures.any?
  warn "\n#{failures.size} icon(s) failed:"
  failures.each { |name, url, reason| warn "  #{name} (#{url}): #{reason}" }
  exit 1
end
