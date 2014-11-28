require 'pg'
require 'rest-client'

class Movie

  def initialize
    @db = PG.connect(host: 'localhost', dbname: 'movie_db')
    @url = "http://movies.api.mks.io/"
    drop_tables
    create_movies_table
    create_actors_table
    create_actors_movies_table
  end

  def drop_tables
    @db.exec("drop table movies;")
    @db.exec("drop table actors")
    @db.exec("drop table actors_movies")
  end

  def get_movies
    initial_movies = RestClient.get(@url + "movies")
    movies = JSON.parse(initial_movies)
    movies
  end

  def get_actors
    initial_actors = RestClient.get(@url + "actors")
    actors = JSON.parse(initial_actors)
    actors
  end


  def get_actors_movies
  end

  def create_movies_table
    sql = %q[
      CREATE TABLE IF NOT EXISTS movies (
        movie_id INT,
        title VARCHAR
        )
      ]
    @db.exec(sql)
  end

  def create_actors_table
    sql = %q[
      CREATE TABLE IF NOT EXISTS actors (
        actor_id INT,
        name VARCHAR
        )
      ]
    @db.exec(sql)
  end

  def create_actors_movies_table
    sql = %q[
      CREATE TABLE IF NOT EXISTS actors_movies (
        id SERIAL,
        actor_id INT,
        movie_id INT
        )
      ]
    @db.exec(sql)
  end

  def save_movies
    movies = get_movies
    movies.each do |movie|
      movie_id = movie['id']
      title = movie['title']
      sql = %q[
        INSERT INTO movies (movie_id, title)
        VALUES ($1, $2)
        ]
      @db.exec(sql, [movie_id, title])
    end
  end

  def save_actors
    actors = get_actors
    actors.each do |actor|
      actor_id = actor['id']
      name = actor['name']
      sql = %q[
        INSERT INTO actors (actor_id, name)
        VALUES ($1, $2)
        ]
      @db.exec(sql, [actor_id, name])
    end
  end

  def get_save_actors_movies
    actors = get_actors
    actors.each do |actor|
      initial_actors_movies = RestClient.get(@url + "actors/" + "#{actor['id']}" + "/movies")
      actors_movies = JSON.parse(initial_actors_movies)
      actors_movies.each do |movie|
        actor_id = actor['id']
        movie_id = movie['id']
        sql = %q[
          INSERT INTO actors_movies (actor_id, movie_id)
          VALUES ($1, $2)
          ]
        @db.exec(sql, [actor_id, movie_id])
      end
    end
  end

  def alphabetical_actors #show all actors in alphabetical order (exercise )
    sql = %q[
      SELECT name
      FROM actors
      ORDER BY name ASC
      ]
    alpha = @db.exec(sql)
    puts "Actors alphabetically: "
    alpha.entries.each do |x|
      puts "#{x['name']}"
    end
  end

  def alphabetical_movies
    sql = %q[
      SELECT title
      FROM movies
      ORDER BY title ASC
      ]
    alpha = @db.exec(sql)
    puts "Movies alphabetically: "
    alpha.entries.each do |x|
      puts "#{x['title']}"
    end
  end

  # def 

  # def frequent_actor
  #   actors = get_actors
  #   actors.each do |x|
  #     total_initial = RestClient.get(@url + "actors" + "/" + "#{x['id']}" + "/movies")
  #     total = JSON.parse(total_initial)
  #     puts "#{x['name']} #{total.length}"
  #   end
  # end

  def actor_frequency #exercsie 9: this queries the db for a list with actors and their movie appearance total
    sql = %q[
      SELECT a.name, count(q.actor_id)
      FROM actors_movies q
      JOIN actors a 
      ON a.actor_id = q.actor_id
      GROUP BY a.name
      ORDER BY COUNT(q.actor_id)
      DESC
      ]
    freq = @db.exec(sql)
    puts "Actor  |  Appearances"
    puts "--------------------------"
    freq.entries.each do |x|
      puts "#{x['name']} | #{x['count']}"
    end
  end

  def show_actors(movie)
    sql1 = %q[
      SELECT movie_id 
      FROM movies
      WHERE title = $1
      ] 
    response = @db.exec(sql1, [movie])
    if !response.entries.empty?
      movie_id = response.entries.first['movie_id']

      sql2 = %q[
        SELECT a.name as actors, m.title as movies
        FROM actors_movies q
        JOIN actors a
        ON a.actor_id = q.actor_id
        JOIN movies m 
        ON m.movie_id = q.movie_id
        WHERE q.movie_id = $1;
        ]
      result = @db.exec(sql2, [movie_id])
      puts "Actors in #{movie}:"
      result.entries.each do |x|
        puts "#{x['actors']}"
      end
    else
      movie_suggest = "%" + movie + "%"
      sql3 = %q[
        SELECT title 
        FROM movies
        WHERE title ilike $1;
        ]
      suggest = @db.exec(sql3, [movie_suggest])
      if !suggest.entries.empty?
        puts "Is it possible you meant to search for: "
        suggest.entries.each do |x|
          puts "#{x['title']}"
        end
      else
        sql4 = %q[
          SELECT title 
          FROM movies
          LIMIT 4;
          ]
        last_chance = @db.exec(sql4)
        puts "I have no suggestions based on your input. Try one of these:"
        last_chance.entries.each do |x|
          puts "#{x['title']}"
        end
      end
    end
  end

  def show_movies(actor)
      sql1 = %q[
        SELECT actor_id 
        FROM actors
        WHERE name = $1
        ] 
    response = @db.exec(sql1, [actor])
    if !response.entries.empty?
      actor_id = response.entries.first['actor_id']

      sql2 = %q[
        SELECT a.name as actors, m.title as movies
        FROM actors_movies q
        JOIN actors a
        ON a.actor_id = q.actor_id
        JOIN movies m
        ON m.movie_id = q.movie_id
        WHERE q.actor_id = $1;
        ]
      result = @db.exec(sql2, [actor_id])
      puts "Movies featuring #{actor}:"
      result.entries.each do |x|
        puts "#{x['movies']}"
      end
    else
      actor_suggest = "%" + actor + "%"
      sql3 = %q[
        SELECT name
        FROM actors
        WHERE name ilike $1;
        ]
      suggest = @db.exec(sql3, [actor_suggest])
      if !suggest.entries.empty?
        puts "Is it possible you meant to search for: "
        suggest.entries.each do |x|
          puts "#{x['name']}"
        end
      else
        sql4 = %q[
          SELECT name
          FROM actors
          LIMIT 4;
          ]
        last_chance = @db.exec(sql4)
        puts "I have no suggestions based on your input. Try one of these:"
        last_chance.entries.each do |x|
          puts "#{x['name']}"
        end
      end
    end
  end

  def co_acted(actor)
    sql1 = %q[
      SELECT actor_id
      FROM actors
      WHERE name = $1
      ]
    response = @db.exec(sql1, [actor])
    actor_id = response.entries.first['actor_id']
    sql2 = %q[
      SELECT *
      FROM actors_movies
      WHERE actor_id = $1
      ]
    result = @db.exec(sql2, [actor_id])
    ary = [actor]
    puts "Actors who have acted with #{actor}:"
    result.entries.each do |x|
      movie_temp = x['movie_id']
      sql3 = %q[
        SELECT a.name as actors, m.title as movies
        FROM actors_movies q
        JOIN actors a
        ON a.actor_id = q.actor_id
        JOIN movies m 
        ON m.movie_id = q.movie_id
        WHERE q.movie_id = $1
        ]
      r_temp = @db.exec(sql3, [movie_temp])
      r_temp.entries.each do |y|
        if !ary.include?(y['actors'])
          ary.push(y['actors'])
        end
      end
    end
    ary.shift
    puts ary
  end

  def movies_in_common(actor1, actor2)
    sql = %q[
      SELECT m.title
      FROM actors_movies q
      JOIN movies m
      ON m.movie_id = q.movie_id
      JOIN actors a
      ON a.actor_id = q.actor_id
      WHERE a.name = $1
      INTERSECT
      SELECT m.title
      FROM actors_movies q
      JOIN movies m
      ON m.movie_id = q.movie_id
      JOIN actors a
      ON a.actor_id = q.actor_id
      WHERE a.name = $2
      ]
    result = @db.exec(sql, [actor1, actor2])
    if !result.entries.empty?
      puts "#{actor1} and #{actor2} have acted together in:"
      result.entries.each do |x|
        puts "#{x['title']}"
      end
    else
      puts "According to our database, these two actors have never shared the screen."
    end
  end

  def show_actors_by_id(movie_id)

    sql1 = %q[
      SELECT title
      FROM movies
      WHERE movie_id = $1
      ]
    result_title = @db.exec(sql1, [movie_id])
    movie_title = result_title.entries.first['title']

    sql2 = %q[
      SELECT a.name as actors, m.title as movies
      FROM actors_movies q
      JOIN actors a
      ON a.actor_id = q.actor_id
      JOIN movies m 
      ON m.movie_id = q.movie_id
      WHERE q.movie_id = $1;
      ]
    result = @db.exec(sql2, [movie_id])
    if !result.entries.empty?
      puts "Actors in #{movie_title}: id - #{movie_id}:"
      result.entries.each do |x|
        puts "#{x['actors']}"
      end
    end
   
  end

  def show_movies_by_id(actor_id)

    sql1 = %q[
      SELECT name
      FROM actors
      WHERE actor_id = $1
      ]
    result_name = @db.exec(sql1, [actor_id])
    actor_name = result_name.entries.first['name']

    sql2 = %q[
      SELECT a.name as actors, m.title as movies
      FROM actors_movies q
      JOIN actors a
      ON a.actor_id = q.actor_id
      JOIN movies m
      ON m.movie_id = q.movie_id
      WHERE q.actor_id = $1;
      ]
    result = @db.exec(sql2, [actor_id])
    if !result.entries.empty?
      puts "Movies featuring #{actor_name}: id - #{actor_id}:"
      result.entries.each do |x|
        puts "#{x['movies']}"
      end
    end

  end

end

# blah = Movie.new
# blah.save_actors
# blah.save_movies
# blah.get_save_actors_movies
# blah.alphabetical_actors
# blah.alphabetical_movies
# blah.actor_frequency
# blah.show_actors_by_id(8)
# blah.show_actors("Heat")
# blah.show_movies_by_id(3)
# blah.show_movies("Robert DeNiro")
# blah.co_acted("Robert DeNiro")
# blah.movies_in_common("Al Pacino", "Robert DeNiro")
# blah.movies_in_common("Tom Hardy", "Guy Pearce")
# blah.movies_in_common("eyx", "xyx")
# blah.show_movies("rob")
# blah.show_movies("xyx")
# blah.show_actors("heat")
# blah.show_actors("eAt")
# blah.show_actors("xqx")
# blah.frequent_actor


class CLI

  def self.command_list
    puts "Command List:"
    puts "  1. Retrieve a list of all movies."
    puts "  2. Retrieve a list of all actors."
    puts "  3. Find all actors by movie ID or title."
    puts "  4. Find all movies an actor was in by ID or name."
    puts "  5. Given an actor, find all other actors they have costared with."
    puts "  6. Exit"
    puts "(please wait for arrow...)"
    puts ""
  end

  def self.start
    running = true
    while running do   
      command_list

      @connection = Movie.new
      @connection.save_movies
      @connection.save_actors
      @connection.get_save_actors_movies

      print "===> "
      input = gets.chomp.to_i

      case input
      when 1
        all_movies
      when 2
        all_actors
      when 3
        puts "Search by ID or title (enter one):"
        input3 = gets.chomp
        if input3 == "ID"
          puts "Enter the ID of the movie:"
          input3_1 = gets.chomp
          actors_by_id(input3_1)
        else
          puts "Enter movie title:"
          input3_2 = gets.chomp
          actors_by_movie(input3_2)
        end

      when 4
        puts "Search by ID or name (enter one):"
        input4 = gets.chomp
        if input4 == "ID"
          puts "Enter the ID of the actor:"
          input4_1 = gets.chomp
          movies_by_id(input4_1)
        else
          puts "Enter actor's name:"
          input4_2 = gets.chomp
          movies_by_actor(input4_2)
        end
        
      when 5
        puts "What is the actor's name:"
        input5 = gets.chomp
        costarring(input5)

      when 6
        running = false
        return
      end

    end

  end

  def self.all_movies
    @connection.alphabetical_movies
  end

  def self.all_actors
    @connection.alphabetical_actors
  end

  def self.actors_by_id(input)
    @connection.show_actors_by_id(input)
  end

  def self.actors_by_movie(input)
    @connection.show_actors(input)
  end

  def self.movies_by_id(input)
    @connection.show_movies_by_id(input)
  end

  def self.movies_by_actor(input)
    @connection.show_movies(input)
  end

  def self.costarring(input)
    @connection.co_acted(input)
  end




end

CLI.start