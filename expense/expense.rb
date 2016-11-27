#! /usr/bin/env ruby

require "pg"




class ExpenseData
  def initialize
    @connection= PG.connect(dbname: "expenses")
  end

  def list_expenses
    results = @connection.exec("select * from expenses order by created_on asc")
    display_expenses(results)
  end

  def add_expense(amount, memo)
    date = Date.today
    sql = "insert into expenses (created_on, amount, memo) values ($1, $2, $3)"
    @connection.exec_params(sql, [amount, date, memo]) 
  end

  def search_expenses(criteria)
    sql = "select * from expenses where memo ILIKE $1"
    result = @connection.exec_params(sql, ["%#{criteria}%"])
    display_expenses(result)
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

  private 

  def display_expenses(expenses)
    expenses.each do |tuple|
      columns = [ tuple["id"].rjust(3),
                  tuple["created_on"].rjust(10),
                  tuple["amount"].rjust(12),
                  tuple["memo"] ]

      puts columns.join(" | ")
    end
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

