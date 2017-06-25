require 'thor'
require 'json'
require 'date'

require_relative 'buffet/interpreter'
require_relative 'buffet/csv_parser'
require_relative 'buffet/types'
require_relative 'buffet/google_sheets_uploader'
require_relative '../config'
require_relative 'colored_text'

module Buffet
  extend self

  class CLI < Thor
    desc "scan FILE [FILE2...]", "scans CSV files and reports how many transactions they include and how many have been imported"
    def scan(*filenames)
      already_imported = []
      with_new_data = []
      transactions_by_account = load_transactions_by_account

      filenames.each do |filename|
        account = CSVParser.parse(filename)
        account_name = account.account_name

        num_already_imported = 0
        if transactions_by_account.has_key?(account_name)
          account.transactions.each do |transaction|
            if transactions_by_account[account_name].any? {|t| t.hash == transaction.hash}
              num_already_imported += 1
            end
          end
        end

        num_new_transactions = account.transactions.size - num_already_imported
        summary = "[#{filename}] #{num_new_transactions} new transactions, #{num_already_imported} already imported to \"#{account_name}\""
        if num_new_transactions == 0
          already_imported << summary
        else
          with_new_data << summary
        end
      end

      unless already_imported.empty?
        puts "\n## Already imported ##"
        puts already_imported
      end
      unless with_new_data.empty?
        puts "\n## With new data ##"
        puts with_new_data
      end
    end

    desc "import FILE [FILE2...]", "imports CSV files"
    def import(*filenames)
      ensure_files_arent_already_imported(filenames)

      log_notes = []
      transactions_by_account = load_transactions_by_account

      parse_csv_files(filenames).each do |account|
        account_name = account.account_name

        if transactions_by_account.has_key?(account_name)
          transactions_by_account[account_name] += account.transactions
        else
          transactions_by_account[account_name] = account.transactions
        end

        log_notes << "#{Date.today}\tImported #{account.transactions.size} transactions to \"#{account_name}\" [#{account.filename}]"
      end

      # Convert all the Transaction structs to hashes so we can easily serialize
      # to JSON
      transactions_by_account = transactions_by_account.reduce({}) do |acc, (account_name, transactions)|
        acc[account_name] = transactions.map(&:to_h)
        acc
      end

      write_json_data(transactions_by_account)
      write_log_notes(log_notes)
    end

    desc "export FILE", "writes all transactions to FILE as CSV"
    def export(filename=nil)
      unless filename
        filename = "./transactions-#{Time.now.strftime("%m-%d-%y")}.csv"
      end

      CSV.open(filename, "w") do |csv|
        csv << ["Account", "Date", "Amount", "Description", "Check number", "Type"]

        transactions = load_transactions

        transactions.each do |t|
          csv << [t.account, t.date, t.amount, t.description, t.check_number, t.transaction_type]
        end
      end
    end

    desc "repl", "interactive programming environment"
    def repl
      env = Buffet::Interpreter.new(load_transactions, load_envrc).repl

      save_env(env)
    end

    desc "tag", "interactively tag transactions"
    def tag
      tagging = true
      transactions = load_transactions_by_account.reduce({}) do |acc, (name, ts)|
        acc[name] = ts.map do |t|
          if tagging
            if t.untagged?
              puts t.format

              tags = apply_tag_rules(t).map {|tag| apply_tag_implications(tag)}.flatten.uniq
              unless tags.empty?
                print "\t\t"
                puts (tags.map do |tag|
                  if tag == "ignore"
                    yellow_text("[#{tag}]")
                  elsif Buffet::Config::PRIMARY_TAGS.include?(tag)
                    light_blue_text("[#{tag}]")
                  else
                     "[#{tag}]"
                  end
                end).join(" ")
              end

              print "tags > "
              input = STDIN.gets.chomp.downcase

              if input == 'q' || input == 'quit'
                tagging = false
              else
                tags += input.split(/,\s*/).
                  map {|tag| expand_tag(tag) }.
                  map {|tag| apply_tag_implications(tag)}.
                  flatten

                tags = tags.uniq
                unknown = tags.select {|tag| !Buffet::Config::PRIMARY_TAGS.include?(tag) && !Buffet::Config::TAGS.include?(tag)}

                if unknown.empty?
                  t.tags = tags
                else
                  puts "Unknown tags: #{unknown.join(", ")}"
                  tagging = false
                end
              end
            end
          end
          t.to_h
        end
        acc
      end

      write_json_data(transactions)
    end

    desc "untagged", "show untagged transactions"
    def untagged
      puts load_transactions.select(&:untagged?).map(&:format)
    end

    desc "debug", "show count of transactions without tags and primary tags"
    def debug
      transactions = load_transactions

      with_primary_tag = transactions.
        reject(&:ignored?).
        reject(&:untagged?).
        select {|t| t.tags.any? {|tag| Buffet::Config::PRIMARY_TAGS.include?(tag)}}

      without_primary_tag = transactions.
        reject(&:ignored?).
        reject(&:untagged?).
        reject {|t| t.tags.any? {|tag| Buffet::Config::PRIMARY_TAGS.include?(tag)}}

      puts "#{with_primary_tag.size} with primary tag"
      puts "#{transactions.select(&:ignored?).size} ignored"
      puts "#{transactions.select(&:untagged?).size} no tags"
      puts "#{without_primary_tag.size} no primary tag"

      puts
      puts without_primary_tag.map(&:format)
    end

    desc "upload", "uploads data to Google Sheets"
    option :transactions, desc: "Upload individual transactions", aliases: [:t]
    def upload(*filenames)
      uploader = GoogleSheetsUploader.new

      spreadsheet_id = Buffet::Config::GOOGLE_SHEETS_ID

      if options[:transactions]
        range = "#{Buffet::Config::GOOGLE_SHEETS_TRANSACTIONS_SHEET}"

        values = load_transactions.map {|t| [t.date, t.description, t.amount, t.tags ? t.tags.first : nil]}
        value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)

        uploader.service.update_spreadsheet_value(spreadsheet_id, range, value_range, value_input_option: "USER_ENTERED") # or RAW
      else
        range = "#{Buffet::Config::GOOGLE_SHEETS_SPENDING_SHEET}"
        transactions_by_month = load_transactions.group_by do |t|
          MonthYear.new(t.rdate)
        end
        sorted_months = transactions_by_month.keys.sort

        values = [[nil] + sorted_months.map(&:to_date)] # first row is header of months
        (Buffet::Config::PRIMARY_TAGS + ['unknown']).each do |tag|
          row = [tag] + sorted_months.map do |month|
            transactions_by_month[month].reduce(0) do |total, transaction|
              if tag == 'unknown'
                if transaction.tags.nil? || ((transaction.tags - Buffet::Config::PRIMARY_TAGS.to_a) == Buffet::Config::PRIMARY_TAGS.to_a)
                  total + transaction.amount.abs
                else
                  total
                end
              else
                if transaction.tags && transaction.tags.include?(tag)
                  total + transaction.amount.abs
                else
                  total
                end
              end
            end
          end
          values << row
        end
        value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)

        uploader.service.update_spreadsheet_value(spreadsheet_id, range, value_range, value_input_option: "USER_ENTERED") # or RAW
      end
    end

    desc "stats", "stats for data in transactions DB"
    def stats
      all_transactions = load_transactions
      by_account = load_transactions_by_account

      max_len = by_account.keys.map(&:size).max

      lines = by_account.map do |account_name, ts|
        "#{" " * (max_len - account_name.size)}#{account_name}  #{ts.size}"
      end

      total_line = "#{" " * (lines.map(&:size).max - 6 - all_transactions.size.to_s.size)}total  #{all_transactions.size}"

      puts lines
      puts "-" * total_line.size
      puts total_line
    end

    desc "dupes", "show potential duplicates"
    def dupes
      load_transactions.group_by {|t| t.hash}.each do |h, transactions|
        if transactions.size > 1
          puts
          puts transactions.map(&:format)
        end
      end
    end

    desc "common", "show most common descriptions (3x+) without existing rules"
    def common
      load_transactions.group_by(&:description).each do |d, transactions|
        transaction = transactions.first

        if transactions.size > 2
          if Buffet::Config::RULES[transaction.description].nil? || Buffet::Config::RULES[transaction.description].empty?
            puts
            puts "# #{transactions.first.simple_format}"
            puts "\"#{transactions.first.description}\" => [],"
          end
        end
      end
    end

    desc "reapply_implications", "reapply tag implications on all transactions"
    def reapply_implications
      transactions = load_transactions_by_account.reduce({}) do |acc, (name, ts)|
        acc[name] = ts.map do |t|
          t.tags = t.tags.
            map {|tag| expand_tag(tag) }.
            map {|tag| apply_tag_implications(tag)}.
            flatten.
            uniq
          t.to_h
        end
        acc
      end

      write_json_data(transactions)
    end

    private

    def expand_tag(tag)
      Buffet::Config::TAG_ABBREVIATIONS[tag] || tag
    end

    def apply_tag_implications(tag)
      if Buffet::Config::TAG_IMPLICATIONS[tag]
        [tag] + Buffet::Config::TAG_IMPLICATIONS[tag]
      else
        [tag] # every tag implies itself
      end
    end

    def apply_tag_rules(transaction)
      if Buffet::Config::RULES[transaction.description] && !Buffet::Config::RULES[transaction.description].empty?
        Buffet::Config::RULES[transaction.description]
      else
        []
      end
    end

    def parse_csv_files(filenames)
      filenames.map do |filename|
        CSVParser.parse(filename)
      end
    end

    def load_envrc
      begin
        File.open(Buffet::Config::ENV_PATH, "r") do |f|
          f.each_line.reject(&:empty?)
        end
      rescue
        puts "#{Buffet::Config::ENV_PATH} does not exist. Initializing empty environment."
        []
      end
    end

    def save_env(env)
      File.open(Buffet::Config::ENV_PATH, "w") do |f|
        env.each do |name, node|
          f.write(node.raw)
        end
      end
    end

    def load_transactions
      load_transactions_by_account.values.flatten
    end

    def load_transactions_by_account
      File.open(Buffet::Config::TRANSACTIONS_DB_PATH) do |f|
        parsed_json = JSON.parse(f.read)

        parsed_json.reduce({}) do |accounts, (account, ts)|
          accounts[account] = ts.map do |t|
            Transaction.new(*t.values)
          end
          accounts
        end
      end
    end

    def write_json_data(transactions_by_account)
      File.open(Buffet::Config::TRANSACTIONS_DB_PATH, "w") do |f|
        f.write(JSON.pretty_generate(transactions_by_account))
      end
    end

    def write_log_notes(log_notes)
      File.open(Buffet::Config::IMPORT_LOG_PATH, "a") do |f|
        f.write(log_notes.join("\n"))
        f.write("\n") # Trailing newline for better diffs
      end
    end

    def ensure_files_arent_already_imported(filenames)
      File.open(Buffet::Config::IMPORT_LOG_PATH, "r") do |f|
        log = f.read
        filenames.each do |filename|
          if log.include?(filename)
            raise "A file named #{filename} has already been imported. Check the log: #{Buffet::Config::IMPORT_LOG_PATH}"
          end
        end
      end
    end
  end
end
