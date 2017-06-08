class MonthYear
  attr_accessor :month
  attr_accessor :year

  def initialize(date)
    self.month = date.month
    self.year = date.year
  end

  def to_s
    "#{month}/#{year - 2000}"
  end

  def to_date
    Date.new(year, month, 1)
  end

  def ==(other)
    self.class == other.class && state == other.state
  end
  alias_method :eql?, :==

  def hash
    state.hash
  end

  def <=>(other)
    if year == other.year
      month <=> other.month
    else
      year <=> other.year
    end
  end

  protected
  def state
    [year, month]
  end
end

class Year
  attr_accessor :year

  def initialize(date)
    self.year = date.year
  end

  def to_s
    year.to_s
  end

  def ==(other)
    self.class == other.class && year == other.year
  end
  alias_method :eql?, :==

  def hash
    year
  end

  def <=>(other)
    year <=> other.year
  end
end
