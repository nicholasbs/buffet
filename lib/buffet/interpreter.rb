require './lib/colored_text'
require './lib/buffet/types'

class BuffetInterpreter
  def self.tag_filter(x, tags_to_include, tags_to_exclude)
    if is_list_of_transactions?(x)
      x.select do |transaction|
        (!tags_to_include.empty? && has_tag(transaction, tags_to_include)) || (!tags_to_exclude.empty? && does_not_have_tag(transaction, tags_to_exclude))
      end
    else
      raise "`tag_filter`: unexpected type #{type_str(x)}"
    end
  end

  def self.search(x, query)
    if is_list_of_transactions? x
      x.select {|transaction| transaction.description =~ /#{query}/i}
    else
      raise "`search`: unexpected type #{type_str(x)}"
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
      raise "`sum`: unexpected type #{type_str(x)}"
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
      raise "`count`: unexpected type #{type_str(x)}"
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
      raise "`avg`: unexpected type #{type_str(x)}"
    end
  end

  def self.last(x, n)
    if is_list? x
      x.last(n)
    else
      raise "`last`: unexpected type #{type_str(x)}"
    end
  end

  def self.reverse(x)
    if is_list? x
      x.reverse
    else
      raise "`reverse`: unexpected type #{type_str(x)}"
    end
  end

  def self.monthly(x)
    if is_list_of_transactions? x
      x.group_by {|t| MonthYear.new(t.rdate)}.
        sort_by {|(m,_)| m}
    else
      raise "`monthly`: unexpected type #{type_str(x)}"
    end
  end

  def self.yearly(x)
    if is_list_of_transactions? x
      x.group_by {|t| Year.new(t.rdate)}.
        sort_by {|(y,_)| y}
    else
      raise "`yearly`: unexpected type #{type_str(x)}"
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
    end

    puts pink_text(type_str(x))
  end
end

# Type helpers

def is_transaction?(x)
  x.is_a? Transaction
end

def is_list_of_transactions?(x)
  is_list?(x) && is_transaction?(x[0])
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
  if is_list?(x)
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
