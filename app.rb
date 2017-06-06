require_relative 'lib/buffet'
require_relative 'lib/error'

def validate_config
  primary_tags = Buffet::Config::PRIMARY_TAGS
  tags = Buffet::Config::TAGS
  all_tags = primary_tags | tags

  unless (primary_tags & tags).empty?
    fatal_error("A tag cannot be both a primary and a regular tag: #{(primary_tags & tags).to_a}")
  end

  tags_used = Set.new(
    (Buffet::Config::TAG_ABBREVIATIONS.values +
     Buffet::Config::TAG_IMPLICATIONS.to_a +
     Buffet::Config::RULES.values).flatten)

  unless tags_used.subset? all_tags
    fatal_error("Undefined tags: #{(tags_used - all_tags).to_a}")
  end
end

validate_config
Buffet::CLI.start(ARGV)
