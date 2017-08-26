require 'strscan'

module Buffet
  class Parser
    def self.parse(string)
      scanner = StringScanner.new(string)
      if name = scanner.scan(/[A-Z]+\w*[^:]:/)
        Alias.new(name[0..-2], parse_expr(scanner), string)
      else
        parse_expr(scanner)
      end
    end

    def self.parse_expr(scanner)
      command = parse_command(scanner)

      scanner.skip(/\s*/)

      if scanner.eos?
        Expr.new(command, nil)
      else
        scanner.skip(/\s*#{Buffet::Config::COMMAND_SEPARATOR}\s*/)
        Expr.new(command, parse_expr(scanner))
      end
    end

    def self.parse_command(scanner)
      scanner.skip(/\s*/)

      if scanner.match?(/!?\[\w+\w|\s*\]/)
        Command.new("tags", parse_tags(scanner))
      else
        keyword = scanner.scan(/([A-Za-z]+)|\//)
        scanner.skip(/\s*/)

        if keyword == "/"
          arg = scanner.scan(/[^#{Buffet::Config::COMMAND_SEPARATOR}]*/)
          Command.new("search", arg.strip)
        elsif keyword == "last"
          arg = scanner.scan(/\d+/)
          Command.new(keyword, arg.to_i)
        else
          Command.new(keyword, nil)
        end
      end
    end

    def self.parse_tags(scanner)
      scanner.skip(/\s*/)

      tag = parse_tag(scanner)

      scanner.skip(/\s*/)

      if scanner.match?(/!|\[/)
        Tags.new(tag, parse_tags(scanner))
      else
        Tags.new(tag, nil)
      end
    end

    def self.parse_tag(scanner)
      scanner.skip(/\s*/)
      negated = scanner.scan(/!/)

      scanner.skip(/\[/)
      name = scanner.scan(/\w+(\s*\w+)?[^\]]/)
      scanner.skip(/\]/)

      Tag.new(name, !!negated)
    end

    Expr = Struct.new(:cmd, :next)
    Alias = Struct.new(:name, :expr, :raw)
    Command = Struct.new(:keyword, :arg)
    Tags = Struct.new(:tag, :next)
    Tag = Struct.new(:name, :negated)
  end
end
