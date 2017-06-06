def colorize_text(color_code, str)
  "\e[#{color_code}m#{str}\e[0m"
end

def red_text(str)
  colorize_text(31, str)
end

def green_text(str)
  colorize_text(32, str)
end

def yellow_text(str)
  colorize_text(33, str)
end

def blue_text(str)
  colorize_text(34, str)
end

def pink_text(str)
  colorize_text(35, str)
end

def light_blue_text(str)
  colorize_text(36, str)
end
