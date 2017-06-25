require 'readline'

require_relative 'parser'
require_relative 'types'
require_relative '../colored_text'

module Buffet
  class Interpreter
    def initialize(reg, envrc=[])
      @env = {}
      @reg = reg
      @initial_reg = reg.dup

      envrc.each do |line|
        evaluate(Buffet::Parser.parse(line))
      end
    end

    def self.reset(x)
      x.dup
    end

    def self.tag_filter(x, tags_to_include, tags_to_exclude)
      if is_list_of_transactions?(x)
        x.select do |transaction|
          (!tags_to_include.empty? && has_tag(transaction, tags_to_include)) || (!tags_to_exclude.empty? && does_not_have_tag(transaction, tags_to_exclude))
        end
      else
        type_error("tag_filter", x)
      end
    end

    def self.search(x, query)
      if is_list_of_transactions? x
        x.select {|transaction| transaction.description =~ /#{query}/i}
      else
        type_error("search", x)
      end
    end

    def self.sum(x)
      if is_number? x
        x # No op
      elsif is_list_of_transactions? x
        x.map(&:amount).reduce(&:+)
      elsif is_grouped_numbers? x
        x.map {|(_,val)| val}.reduce(&:+)
      elsif is_grouped_transactions? x
        x.map {|y,ts| [y, ts.map(&:amount).reduce(&:+)]}
      else
        type_error("sum", x)
      end
    end

    def self.count(x)
      if is_number? x
        1
      elsif is_grouped_transactions? x
        x.map {|(y,ts)| [y, ts.size]}
      elsif is_list? x
        x.size
      else
        type_error("count", x)
      end
    end

    def self.avg(x)
      if is_float? x
        x
      elsif is_integer? x
        x.to_f
      elsif is_list_of_transactions? x
        x.map(&:amount).reduce(&:+) / x.size
      elsif is_grouped_transactions? x
        x.map {|(y,ts)| [y, avg(ts)]}
      elsif is_grouped_numbers? x
        x.map {|(_,num)| num.to_f}.reduce(&:+) / x.size
      else
        type_error("avg", x)
      end
    end

    def self.last(x, n)
      if is_list? x
        x.last(n)
      else
        type_error("last", x)
      end
    end

    def self.reverse(x)
      if is_list? x
        x.reverse
      else
        type_error("reverse", x)
      end
    end

    def self.monthly(x)
      if is_list_of_transactions? x
        x.group_by {|t| MonthYear.new(t.rdate)}.
          sort_by {|(m,_)| m}
      else
        type_error("monthly", x)
      end
    end

    def self.yearly(x)
      if is_list_of_transactions? x
        x.group_by {|t| Year.new(t.rdate)}.
          sort_by {|(y,_)| y}
      else
        type_error("yearly", x)
      end
    end

    def self.print(x)
      if is_float?(x)
        puts format_money(x)
      elsif is_integer?(x)
        puts x # integer, e.g., result f `count`
      elsif is_list_of_transactions?(x)
        puts x.map(&:format)
      elsif is_grouped?(x)
        x.map do |(date,y)|
          d = yellow_text(date.to_s)

          if is_list_of_transactions?(y)
            puts d
            puts y.map(&:format)
            puts
          elsif is_float?(y)
            puts "#{d}\t#{format_money(y)}"
          elsif is_integer?(y)
            puts "#{d}\t#{y}"
          end
        end
      elsif is_empty_list?(x)
        puts "[]"
      else
        type_error("print", x)
      end

      puts pink_text(type_str(x))
    end

    # Class methods are all REPL commands
    COMMANDS = singleton_methods.map(&:to_s).sort

    def repl
      Readline.completer_word_break_characters = ""
      Readline.completion_proc = Proc.new do |str|
        if str.end_with?("  ")
          ["#{str[0..-2]}#{Buffet::Config::COMMAND_SEPARATOR}"]
        else
          md = str.match(/(\s*)([^#{Buffet::Config::COMMAND_SEPARATOR}]+)$/)

          if md && md[2]
            whitespace = md[1]
            completable_part = md[2]
            remainder = str[0...(str.size - completable_part.size - whitespace.size)]

            if completable_part.start_with?("[")
              Buffet::Config::ALL_TAGS.sort.select do |tag|
                "[#{tag}" =~ /^#{Regexp.escape(completable_part)}/
              end.map do |option|
                "#{remainder}#{whitespace}[#{option}]"
              end
            else
              (COMMANDS + @env.keys).sort.select do |command|
                command =~ /^#{Regexp.escape(completable_part)}/
              end.map do |option|
                "#{remainder}#{whitespace}#{option}"
              end
            end
          end
        end
      end

      loop do
        line = Readline.readline("> ", true)

        if ["q", "quit"].include?(line)
          break
        else
          begin
            ast = Buffet::Parser.parse(line)
            reg = evaluate(ast)
            Interpreter.print(reg)
          rescue => e
            puts e.message
          end
        end
      end

      @env
    end

    def evaluate(node)
      if node.is_a? Buffet::Parser::Expr
        evaluate_expr(node)
      elsif node.is_a? Buffet::Parser::Alias
        if @env.key?(node.name)
          raise "#{node.name} is already defined"
        end

        @env[node.name] = node
      else
        puts node.class
      end

      @reg
    end

    def evaluate_expr(expr)
      if expr.left.is_a? Buffet::Parser::Expr
        evaluate_expr(expr.left)
      else
        evaluate_command(expr.left)
      end

      if expr.right
        evaluate_expr(expr.right)
      end
    end

    def evaluate_tags(node)
      if node.nil?
        []
      elsif node.is_a? Buffet::Parser::Tag
        [node]
      else
        evaluate_tags(node.left) + evaluate_tags(node.right)
      end
    end

    def evaluate_command(cmd)
      if cmd.keyword == 'search'
        @reg = Interpreter.search(@reg, cmd.arg)
      elsif cmd.keyword == 'reset'
        @reg = Interpreter.reset(@initial_reg)
      elsif cmd.keyword == 'last'
        @reg = Interpreter.last(@reg, cmd.arg)
      elsif cmd.keyword == 'reverse'
        @reg = Interpreter.reverse(@reg)
      elsif cmd.keyword == 'avg'
        @reg = Interpreter.avg(@reg)
      elsif cmd.keyword == 'sum'
        @reg = Interpreter.sum(@reg)
      elsif cmd.keyword == 'count'
        @reg = Interpreter.count(@reg)
      elsif cmd.keyword == 'monthly'
        @reg = Interpreter.monthly(@reg)
      elsif cmd.keyword == 'yearly'
        @reg = Interpreter.yearly(@reg)
      elsif cmd.keyword == 'print'
        @reg = Interpreter.print(@reg)
      elsif cmd.keyword == 'tags'
        tags = evaluate_tags(cmd.arg)
        to_exclude, to_include = tags.partition(&:negated)
        @reg = Interpreter.tag_filter(
          @reg,
          to_include.map(&:name),
          to_exclude.map(&:name)
        )
      elsif @env.key?(cmd.keyword)
        evaluate_expr(@env[cmd.keyword].expr)
      else
        raise "Unknown command: `#{cmd.keyword}`"
      end
    end
  end
end

# Type helpers

def is_transaction?(x)
  x.is_a? Transaction
end

def is_list_of_transactions?(x)
  is_list?(x) && is_transaction?(x[0])
end

def is_empty_list?(x)
  is_list?(x) && x.empty?
end

def is_integer?(x)
  x.is_a? Fixnum
end

def is_float?(x)
  x.is_a? Float
end

def is_number?(x)
  is_integer?(x) || is_float?(x)
end

def is_list?(x)
  x.is_a? Array
end

def is_grouped?(x)
  is_list?(x) && is_list?(x[0])
end

def is_grouped_transactions?(x)
  is_grouped?(x) && is_list_of_transactions?(x[0][1])
end

def is_grouped_numbers?(x)
  is_grouped?(x) && is_number?(x[0][1])
end

def type_str(x)
  if is_list?(x) && !is_empty_list?(x)
    if x[0].class != x[1].class
      "[#{type_str(x[0])}, #{type_str(x[1])}]"
    else
      "[#{type_str(x[0])}]"
    end
  else
    x.class
  end
end

def format_money(amount)
  amount = amount.round(2)

  if amount < 0
    red_text("$#{amount.abs}")
  elsif amount > 0
    green_text("$#{amount}")
  else
    "$#{amount}"
  end
end

def has_tag(transaction, tags)
  transaction.tags.any? {|t| tags.include?(t)}
end

def does_not_have_tag(transaction, tags)
  transaction.tags.all? {|t| !tags.include?(t)}
end

def type_error(func, reg)
  raise "`#{func}`: unexpected type #{type_str(reg)}"
end
