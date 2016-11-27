#! /usr/bin/env ruby

require "pg"
require "io/console"



class ExpenseData
  def initialize
    @connection= PG.connect(dbname: "expenses")
    setup_schema
  end

  def list_expenses
    results = @connection.exec("select * from expenses order by created_on asc")
    display_count(results) 
    display_expenses(results) if results.ntuples > 0
  end

  def add_expense(amount, memo)
    date = Date.today
    sql = "insert into expenses (created_on, amount, memo) values ($1, $2, $3)"
    @connection.exec_params(sql, [amount, date, memo]) 
  end

  def search_expenses(criteria)
    sql = "select * from expenses where memo ILIKE $1"
    result = @connection.exec_params(sql, ["%#{criteria}%"])
    display_count(result) 
    display_expenses(result) if result.ntuples > 0
  end

  def delete_expense(id)
    sql = "select * from expenses where id = $1"
    check = @connection.exec_params(sql, [id])

    if check.ntuples == 1
      sql = "delete from expenses where id = $1"
      @connection.exec_params(sql, [id])

      puts "The following expense has been deleted:"
      display_expenses(check)
    else
      puts "There is no expense with the id #{id}"
    end
  end

  def clear_all_expenses
    @connection.exec("delete from expenses")
    puts "All expenses have been deleted."
  end

  private 

  def display_expenses(expenses)
    expenses.each do |tuple|
      columns = [ tuple["id"].rjust(3),
                  tuple["created_on"].rjust(10),
                  tuple["amount"].rjust(12),
                  tuple["memo"] ]

      puts columns.join(" | ")
    end
    puts "-" * 50 

    amount_sum = expenses.field_values("amount").map(&:to_f).inject(:+)

    puts "Total #{amount_sum.to_s.rjust(25)}"
  end

  def display_count(expenses)
    count = expenses.ntuples
    if count == 0 
      puts "There are no expenses."
    else
      puts "There are #{count} expense#{"s" if count != 1}."
    end
  end

  def setup_schema 
     result = @connection.exec <<-sql
       select count(*) from information_schema.tables 
       where table_schema = 'public' and table_name = 'expenses';
     sql

     if result[0]["count"] == "0"
      @connection.exec <<-sql
        create table expenses (
        id serial primary key,
        amount numeric(6,2) not null check (amount >= 0.01),
        memo text not null,
        created_on date not null
        );
      sql
  end

end

class CLI
  def initialize
    @application = ExpenseData.new
  end
  
  def run(arguments)
    command = arguments.shift
    case command
    when "add"
      amount = arguments[1]
      memo = arguments[2]
      abort "You must provide an amount and memo." unless amount && memo
      @application.add_expense(amount, memo)
    when "list"
      @application.list_expenses
    when "search"
      @application.search_expenses(arguments[0])
    when "delete"
      @application.delete_expense(arguments[0])
    when "clear"
      puts "This will remove all expenses. Are you sure? (y/n)"
      response = $stdin.getch
      @application.clear_all_expenses if response == "y"
    else
      display_help
    end
  end
end


def display_help
  puts <<-HELP
    An expense recording system

    Commands:

    add AMOUNT MEMO [DATE] - record a new expense
    clear - delete all expenses
    list - list all expenses
    delete NUMBER - remove expense with id NUMBER
    search QUERY - list expenses with a matching memo field

  HELP
end

CLI.new.run(ARGV)

