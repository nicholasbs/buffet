require 'set'

# Copy this file to config.rb and edit as desired

module Buffet
  module Config
    # Make sure to create "data" directory
    TRANSACTIONS_DB_PATH = "./data/transactions.db"
    IMPORT_LOG_PATH = "./data/import_log.txt"

    ACCOUNT_NAME_GENERATORS = {
      #"ChaseCSV" => Proc.new {|filename| # ??? }
    }
    ACCOUNT_ALIASES = {
      # "Checking account XXXXXX-123456" => "Schwab Checking",
    }

    MAX_ACCOUNT_LENGTH = 15
    MAX_DESCRIPTION_LENGTH = 52


    # These options are required for `buffet upload`.  You can find
    # GOOGLE_SHEETS_ID by creating a new Google spreadsheet and copying the
    # slug near the end of the URL, e.g.,
    # https://docs.google.com/spreadsheets/d/<GOOGLE_SHEETS_ID>
    #
    # The following assumes your spreadsheet has "Transactions" and "Spending"
    # tabs.
    GOOGLE_SHEETS_ID = '<GOOGLE_SHEETS_ID'
    GOOGLE_SHEETS_TRANSACTIONS_SHEET = 'Transactions'
    GOOGLE_SHEETS_SPENDING_SHEET = 'Spending'
    GOOGLE_CLIENT_SECRET_PATH = 'client_secret.json'

    PRIMARY_TAGS = Set.new [
      "ignore",
      "housing",
      "food",
      "health",
      "entertainment",
      "transportation",
      "travel",
      "utilities",
      "shopping",
      "cash",
      "gifts",
      "special",
      "donations",
    ]

    TAGS = Set.new [
      "eating out",
      "groceries",
      "coffee",
      "taxis",
      "cell",
      "gas",
      "wedding",
      "books",
      "movies",
      "airfare",
      "rent",
      "dental",
      "copay",
      "medical",
      "car rental",
      "gym",
      "drinks",
      "insurance",
      "credit card payment",
      "payroll",
      "transfer",
      "interest",
      "atm rebate",
      "check",
      "internet",
      "lunch",
      "software",
      "transit",
      "beauty",
      "doctor"
    ]

    # tag a transaction as 'f' and it will be tagged 'food'
    TAG_ABBREVIATIONS = {
      "f" => "food",
      "l" => "lunch",
      "e" => "eating out",
      "g" => "groceries",
      "i" => "ignore",
      "t" => "transportation",
      "u" => "utilities",
      "c" => "coffee",
    }

    # tag a transaction as 'groceries' and it will also be tagged 'food'
    TAG_IMPLICATIONS = {
      "eating out" => ["food"],
      "groceries" => ["food"],
      "coffee" => ["food"],
      "drinks" => ["entertainment"],
      "lunch" => ["food", "eating out"],
      "taxis" => ["transportation"],
      "movies" => ["entertainment"],
      "books" => ["shopping"],
      "airfare" => ["travel"],
      "cell" => ["utilities"],
      "gas" =>  ["utilities"],
      "rent" => ["housing"],
      "internet" => ["utilities"],
      "doctor" => ["medical", "health"],
      "copay" => ["medical", "health"],
      "dental" => ["medical", "health"],
      "transit" => ["transportation"],
      "car rental" => ["transportation"],
      "gym" => ["health"],
      "software" => ["shopping"],
      "beauty" => ["health"],
    }

    # Any transaction that matches one of the descriptions below will
    # automatically get the tag(s) on the right.
    #
    # Run `buffet common` for suggestions of what to put here
    RULES = {
      # "Ruby's Cafe - NEW YORK, NY" => ["eating out"],
    }
  end
end
