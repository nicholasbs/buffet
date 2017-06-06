require_relative 'colored_text'

def fatal_error(msg)
  puts red_text(msg)
  exit(1)
end
