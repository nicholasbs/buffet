require 'strscan'

module Buffet
  class Parser
    def self.parse(string)
      scanner = StringScanner.new(string)
      if name = scanner.scan(/[A-Z]+\w*[^:]/)
        scanner.skip(/:\s*/)
        Alias.new(name, parse_expr(scanner))
      else
        parse_expr(scanner)
      end
    end

    def self.parse_expr(scanner)
      command = parse_command(scanner)

      scanner.skip(/\s*/)

      if scanner.eos?
        command
      else
        scanner.skip(/\s*»\s*/)
        Expr.new(command, parse_expr(scanner))
      end
    end

    def self.parse_command(scanner)
      scanner.skip(/\s*/)

      if scanner.match?(/!?\[\w+\w|\s*\]/)
        parse_tags(scanner)
      else
        keyword = scanner.scan(/([a-z]+)|\//)
        scanner.skip(/\s*/)

        if keyword == "/"
          arg = scanner.scan(/[^»]*/)
          Command.new(keyword, arg.strip)
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
      name = scanner.scan(/\w+[^\]]/)
      scanner.skip(/\]/)

      Tag.new(name, !!negated)
    end

    Expr = Struct.new(:left, :right)
    Alias = Struct.new(:name, :expr)
    Command = Struct.new(:keyword, :arg)
    Tags = Struct.new(:left, :right)
    Tag = Struct.new(:name, :negated)
  end
end
