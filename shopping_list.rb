require 'set'
require 'readline'

def load_recipes()
  recipes = {}
  Dir.glob("recipes/*.dish").each do |fname|
    dish_name = /recipes\/([^.]*).dish/.match(fname)[1]
    recipes[dish_name] = File.readlines(fname).map { |ln| ln.chomp }
  end
  return recipes
end

class Env
  def initialize(recipes)
    @shopping_list = {}
    @recipes = recipes
  end
  attr_reader :recipes
  attr_accessor :shopping_list
end

class Commands
  def self.help(env)
    puts ""
    puts "\033[1mList of available commands:\033[0m"
    Commands.methods(false).each do |mname|
      m = Commands.method(mname)
      params = m.parameters.map { |p| p[1].to_s }
      args = ""
      if params.length > 1
        p = params[1..].join(", ")
        args = " -- \e[33m#{p}\e[0m"
      end
      puts "\e[32m#{mname}\e[0m#{args}"
    end
  end

  def self.list_dishes(env)
    env.recipes.keys.sort.each do |recipe|
      puts "\e[33m#{recipe}\e[0m"
    end
  end

  def self.show_recipe(env, dish_name)
    if env.recipes.include?(dish_name)
      env.recipes[dish_name].sort.each do |ingredient|
        puts "\e[33m#{ingredient}\e[0m"
      end
    else
      puts "Cannot find dish #{dish_name}."
    end
  end

  def self.add_dish(env, dish_name)
    if env.recipes.include?(dish_name)
      puts "Adding #{dish_name} to shopping list."
      h = Hash[env.recipes[dish_name].map { |ingredient| [ingredient, Set[dish_name]] }]
      env.shopping_list.merge!(h) { |key, v1, v2| v1 | v2 }
    else
      puts "Could not find recipe for #{dish_name}."
    end
  end

  def self.add_ingredient(env, ingredient)
    h = {ingredient => Set['manual']}
    env.shopping_list.merge!(h) { |key, v1, v2| v1 | v2 }
  end

  def self.remove_dish(env, dish_name)
    env.shopping_list.transform_values! { |s| s.delete(dish_name) }
    env.shopping_list.delete_if { |k, s| s.empty? }
  end

  def self.remove_ingredient(env, ingredient)
    env.shopping_list.delete(ingredient)
  end

  def self.show_shopping_list(env)
    if env.shopping_list.empty?
      puts "\e[33mEmpty\e[0m"
    end
    env.shopping_list.to_a.sort { |a,b| a[0] <=> b[0] }.each do |ingredient, dishes|
      d = dishes.to_a.join(", ")
      puts "\e[32m#{ingredient}\e[0m -- \e[33m#{d}\e[0m"
    end
  end

  def self.save(env)
    File.open('list.txt', 'w') do |file|
      env.shopping_list.to_a.sort { |a,b| a[0] <=> b[0] }.each do |ingredient, dishes|
        d = dishes.to_a.join(", ")
        file.puts "#{ingredient} -- #{d}"
      end
    end
    puts "Success!"
  end
end

def exec_cmd(env, cmd)
  parts = cmd.split
  op = parts[0]
  args = parts[1..]
  if not Commands.methods(false).map { |m| m.to_s }.include?(op)
    puts "No such command."
    return nil
  end
  m = Commands.method(op)
  # Plus 1 for the env.
  if m.parameters.length != args.length + 1
    puts "Wrong args."
    return nil
  end
  Commands.public_send(op, env, *args)
end

recipes = load_recipes()
env = Env.new recipes

Readline.completion_proc = Proc.new do |s|
  ls = Commands.methods(false)
  ls.concat(env.recipes.keys)
  ls.grep(/^#{Regexp.escape(s)}/)
end

loop do
  puts "\033[1mEnter a command. Type help for list of commands. Type quit to leave.\033[0m"
  cmd = Readline.readline('> ', true)
  if cmd.chomp == 'quit'
    puts "K, bye!"
    break
  end
  exec_cmd(env, cmd)
  puts ""
  puts ""
end
