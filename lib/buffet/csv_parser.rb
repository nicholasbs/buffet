require 'csv'
require 'digest'

require_relative '../../config'
require_relative '../colored_text'

class CSVParser
  def self.parse(filename)
    get_csv_parser(filename).new(filename)
  end

private
  CHASE_REGEX = /^Transaction Date,Post Date,Description,Category,Type,Amount/
  CHASE_OLD_REGEX = /^Type,Trans Date,Post Date,Description,Amount(,Category,Memo)?/
  CHASE_CHECKING_REGEX = /^Details,Posting Date,Description,Amount,Type,Balance,Check or Slip #/
  SCHWAB_REGEX = /Transactions\s+for\s+(?<account_name>.*)\s+as\s+of\s+(?<timestamp>.*)/
  BANK_OF_AMERICA_REGEX = /^Description,,Summary Amt\./
  AMEX_REGEX = /^\d{2}\/\d{2}\/\d{4}\s+(Mon|Tue|Wed|Thu|Fri|Sat|Sun),,"/

  def self.get_csv_parser(filename)
    File.open(filename) do |f|
      line = f.readline
      if line =~ CHASE_REGEX
        ChaseCSV
      elsif line =~ CHASE_OLD_REGEX
        ChaseOldCSV
      elsif line =~ CHASE_CHECKING_REGEX
        ChaseCheckingCSV
      elsif line =~ SCHWAB_REGEX
        SchwabCSV
      elsif line =~ BANK_OF_AMERICA_REGEX
        BankOfAmericaCSV
      elsif line =~ AMEX_REGEX
        AmexCSV
      else
        puts("Unknown CSV type. This might be an unsupported bank or the format changed. \n\nHeader:\n#{line}")
        exit 1
      end
    end
  end

  class AbstractCSV
    attr_reader :transactions
    attr_reader :filename

    def debits
      transactions.select(&:debit?)
    end

    def account_name
      class_name = self.class.name.split('::').last
      if Buffet::Config::ACCOUNT_NAME_GENERATORS[class_name]
        Buffet::Config::ACCOUNT_NAME_GENERATORS[class_name].call(filename)
      end
    end
  end

  class BankOfAmericaCSV < AbstractCSV
    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        # Date, Description, Amount, Running Bal.
        8.times { f.readline } # skip first 8 lines

        CSV.parse(f.read).each.with_index do |row, i|
          transactions <<  Transaction.new(
            row_hash(row), # hash
            account_name, # account
            Date.strptime(row[0], "%m/%d/%Y"), # date
            row[2].to_f, # amount
            row[1], # description
            nil, # check number -- N/A
            nil, # transaction type -- N/A
            row[3], # running balance
            nil, # post date -- N/A
            [] # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES["Bank of America"] || "Bank of America"
    end
  end

  class ChaseCSV < AbstractCSV
    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        # Transaction Date 0,Post Date 1,Description 2,Category 3,Type 4,Amount 5
        f.readline # ignore header

        CSV.parse(f.read).each.with_index do |row, i|
          if row.size == 6
            amount = row[5].to_f
            description = row[2]
            type = row[4]
          else
            raise "Error processing Chase CSV: Row #{i} has #{row.size} columns. Maybe transaction has a comma in name?"
          end

          transactions <<  Transaction.new(
            row_hash(row), # hash
            account_name, # account
            Date.strptime(row[0], "%m/%d/%Y"), # date
            amount,
            description,
            nil, #  check number - N/A
            type, # transaction type
            nil, # running balance - N/A
            Date.strptime(row[1], "%m/%d/%Y"), # post date
            [], # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES["Chase"] || "Chase"
    end
  end

  class ChaseOldCSV < AbstractCSV
    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        # Type, Trans Date, Post Date, Description, Amount, Category (unused), Memo (unused)
        f.readline # ignore header

        CSV.parse(f.read).each.with_index do |row, i|
          # Chase does not properly quote its CSV data, so if a transaction
          # name contains a comma the header indices get messed up. Heaven help
          # us if a merchant ever puts *two* commas in its name.

          if row.size == 7 || row.size == 5 # 5 if CSV doesn't include Category and Memo
            amount = row[4].to_f
            description = row[3]
          elsif row.size == 8 || row.size == 6
            amount = row[5].to_f
            description = "#{row[3]}, #{row[4]}"
          else
            raise "Error processing Chase CSV: Row has #{row.size} columns. Maybe transaction has two commas in name?"
          end

          transactions <<  Transaction.new(
            row_hash(row), # hash
            account_name, # account
            Date.strptime(row[1], "%m/%d/%Y"), # date
            amount,
            description,
            nil, #  check number - N/A
            row[0], # transaction type
            nil, # running balance - N/A
            Date.strptime(row[2], "%m/%d/%Y"), # post date
            [], # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES["Chase"] || "Chase"
    end
  end

  class ChaseCheckingCSV < AbstractCSV
    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        # Details,Posting Date,Description,Amount,Type,Balance,Check or Slip #
        f.readline # ignore header

        CSV.parse(f.read).each.with_index do |row, i|
          transactions <<  Transaction.new(
            row_hash(row), # hash
            account_name, # account
            Date.strptime(row[1], "%m/%d/%Y"), # date (posting date, since that's all Chase gives)a
            row[3].to_f, # amount
            row[2], # description
            nil, #  check number
            row[4], # transaction type
            row[5], # running balance
            Date.strptime(row[1], "%m/%d/%Y"), # post date
            [], # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES["Chase checking"] || "Chase checking"
    end
  end

  class AmexCSV < AbstractCSV
    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        CSV.parse(f.read).each.with_index do |row, i|

          amount = row[7].to_f * -1 # make expenses negative and payments positive

          transactions <<  Transaction.new(
            row_hash(row), # hash
            account_name, # account
            Date.strptime(row[0], "%m/%d/%Y"), # date
            amount, # amount
            row[2], # description
            nil, # check number - N/A
            nil, # transaction type - N/A
            nil, # running balance - N/A
            nil, # post data - N/A
            [], # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES["Amex"] || "Amex"
    end
  end

  class SchwabCSV < AbstractCSV
    attr_reader :transactions

    def initialize(filename)
      @filename = filename
      @transactions = []

      File.open(filename) do |f|
        extract_name_and_timestamp(f.readline)

        2.times { f.readline } # hack to skip next two lines

        # Schwab seems to have added an extra header line to their CSVs. This
        # consumes that line if it's there and seeks back one line if it's not
        # (to ensure backwards compatability).
        line_num = f.lineno
        if f.readline != "Posted Transactions"
          f.lineno = line_num
        end

        # 0 date, 1 type, 2 check 3 description, 4 withdraw (-), 5 deposit (+), 6 running balance
        CSV.parse(f.read).each.with_index do |row, i|
          if !row[4].empty? && !row[5].empty?
            puts "ERROR: Row has both widthdraw and deposit amount"
            puts row.join(", ")
            exit 1
          end

          if !row[4].empty? # withdraw amount
            amount = cash_str_to_f(row[4]) * -1
          elsif !row[5].empty? # deposit amount
            amount = cash_str_to_f(row[5])
          end

          transactions <<  Transaction.new(
            row_hash(row), # hash
            @raw_account_name, # account
            Date.strptime(row[0], "%m/%d/%Y"), # date
            amount, # amount
            row[3], # description
            row[2].to_i, # check number
            row[1], # transaction type
            row[6], # running balance
            nil, # post date - N/A
            [], # tags
          )
        end
      end
    end

    def account_name
      super || Buffet::Config::ACCOUNT_ALIASES[@raw_account_name] || @raw_account_name
    end

    private
    NAME_AND_TIMESTAMP_REGEX =
      /Transactions\s+for\s+(?<account_name>.*)\s+as\s+of\s+(?<timestamp>.*)$/

    def extract_name_and_timestamp(header)
      md = NAME_AND_TIMESTAMP_REGEX.match(header)

      if not md
        puts "Error processing account name and time stamp"
        exit 1
      end

      @raw_account_name = md[:account_name]
      @timestamp = md[:timestamp]
    end
  end
end

Transaction = Struct.new(:hash, :account, :date, :amount, :description, :check_number, :transaction_type, :running_balance, :post_date, :tags, :original_amount) do
  def format
    tag_str = tags.sort_by do |t1,t2|
        # List primary tags first
        Buffet::Config::PRIMARY_TAGS.include?(t2).to_s <=> Buffet::Config::PRIMARY_TAGS.include?(t1).to_s
    end.map do |tag|
      if Buffet::Config::PRIMARY_TAGS.include?(tag)
        blue_text("[#{tag}]")
      else
        light_blue_text("[#{tag}]")
      end
    end.join(" ")

    desc = trunacte_or_pad_to(description, Buffet::Config::MAX_DESCRIPTION_LENGTH)
    acc = trunacte_or_pad_to(account_name, Buffet::Config::MAX_ACCOUNT_LENGTH)

    s = "\t#{yellow_text(date)} #{desc} #{acc} #{tag_str}"

    if amount < 0
      "#{red_text(amount)}#{s}"
    elsif amount > 0
      "#{green_text(amount)}#{s}"
    else
      "#{amount}#{s}"
    end
  end

  def simple_format
    "#{amount} #{date} #{description} #{account_name}"
  end

  def account_name
    Buffet::Config::ACCOUNT_ALIASES[account] || account
  end

  def debit?
    amount < 0.0
  end

  def ignored?
    tags.include?("ignore")
  end

  def untagged?
    tags.nil? || tags.empty?
  end

  def rdate
    @rdate || @rdate = Date.strptime(date, "%Y-%m-%d")
  end
end

# Helpers

def row_hash(row)
  Digest::SHA256.hexdigest(row.join("_@_@_"))
end

def cash_str_to_f(str)
  str[1..-1].gsub(",", "").to_f # "$2,000.99" -> 2000.99
end

def trunacte_or_pad_to(str, len)
  if str.length < len
    str + " " * (len - str.length)
  else
    str[0...len]
  end
end
