# app.rb

#http://www.sinatrarb.com/
require 'sinatra'
#https://github.com/lostisland/faraday
require 'faraday'
#http://ruby-doc.org/stdlib-2.0.0/libdoc/json/rdoc/JSON.html
require 'json'
#https://github.com/janko-m/sinatra-activerecord
require "sinatra/activerecord"
# bundle exec irb -I. -r app.rb

#https://api.slack.com/slash-commands

Dir[File.join(File.dirname(__FILE__), '.',  'models', '**/*.rb')].sort.each do |file|
  require file
end

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/development_slacktictactoe')

before do
  #logging params for debuggin
  logger.info params
  unless params['token'] == 'q0495fW1oJbatYijLFbjovIg' # ENV['slack_token']
    #401 Unauthorized response should be used for missing or bad authentication, and a 403 Forbidden response should be used afterwards, when the user is authenticated but isn’t authorized to perform the requested operation on the given resource.
    halt 401, 'Your token is incorrect'
  end

  @conn = Faraday.new(url: params['response_url'], headers: {:'Content-Type' => 'application/json'}) do |faraday|
    faraday.request  :url_encoded             # form-encode POST params
    faraday.response :logger                  # log requests to STDOUT
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
  end
  @channel_id = params['channel_id']
  @current_player = "@" << params['user_name']
end

set(:routing) do |value|   # <- notice the splat here
  condition do
    unless (/\A#{value}/.match(params['text'])) ; return false ; end
  end
end

post '/', :routing => 'play' do
  unless !Game.games_finished_in_channel?(@channel_id)
    halt 200, "There are currently no active games being played in this channel. Type /tictactoe [challenge @buddy] to start one!"
  else
    #match a digit only if there is not a non-whitespace character before it, and there is not a non-whitespace character after it
    number_regex = /(?<!\S)\d(?!\S)/
    g = Game.where(finished: false).where(channel_id: @channel_id)[0]

    if params['text'] =~ number_regex
      position = number_regex.match(params['text'])[0]
      if g.valid_move?(position)
        if g.current_player[:player] == @current_player
          g.game[position.to_i - 1] = g.current_player[:move]
          g.update(game: g.game)
          if g.finished?
            g.update_column(:finished, true)
            if g.won?
              text = "Congratulations #{g.won?[:player]}! You won!!!! Challenge another buddy and continue your winning streak!"
            elsif g.draw?
              text = "Cats game! Challenge your buddy again for a rematch!"
            end
          else
            text = "Good move #{@current_player}. It's your turn #{g.current_player[:player]}!"
          end
        else
          halt 400, 'It\'s not your turn!'
        end
      else
        halt 400, 'This position has already been taken!'
      end
    else
      halt 400, 'Please play a valid move!'
    end

    json = {
      text: text,
      response_type: 'in_channel',
      mrkdwn: true,
      attachments: [
        {
          text: g.represent,
          color: '#00a0ff'
        }
      ]
    }

    @conn.post do |req|
      req.body = JSON.generate(json)
    end
  end
end

post '/', :routing => 'challenge' do
  unless Game.games_finished_in_channel?(@channel_id)
    halt 200, "There is currently a game being played in this channel. Type /tictactoe [end] to end the current game or wait until the current game is over."
  else
    mention_regex = /@([a-z0-9]+)/
    if params['text'] =~ mention_regex
      @playerO = mention_regex.match(params['text'])[0]
    else
      halt 400, 'Did you forget to challenge a @buddy?'
    end

    g = Game.new(playerX: @current_player, playerO: @playerO, channel_id: @channel_id)

    if g.valid?
      g.save!
    else
      halt 500, g.errors.full_messages.join("\n")
    end

    json = {
      text: "Lets do this! #{@current_player} *(X)* challenges #{@playerO} *(O)* to a game of TicTacToe!\n #{@current_player} moves first. Type /tictactoe play [1-9].",
      response_type: 'in_channel',
      mrkdwn: true,
      attachments: [
        {
          text: g.represent
        }
      ]
    }

    @conn.post do |req|
      req.body = JSON.generate(json)
    end
  end
end

post '/', :routing => 'status' do
  if Game.games_finished_in_channel?(@channel_id)
    halt 200, "There are no games being played right now. Feel free to start your own!"
  else
    g = Game.where(finished: false).where(channel_id: @channel_id)[0]
    text = "#{g.playerX} *(X)* vs #{g.playerO} *(O)* in progress. It\'s #{g.current_player[:player]}\'s turn!"
    json = {
      text: text,
      mrkdwn: true,
      response_type: 'in_channel',
      attachments: [
        {
          text: g.represent,
          color: '#00a0ff'
        }
      ]
    }

    @conn.post do |req|
      req.body = JSON.generate(json)
    end
  end

end

post '/', :routing => 'end' do
  Game.where(channel_id: @channel_id).update_all(finished: true)

  text = "*Ending all active games in this channel. Feel free to start a new one.*"
  json = {
    text: text,
    response_type: 'in_channel',
    mrkdwn: true
  }

  @conn.post do |req|
    req.body = JSON.generate(json)
  end
end

post '/', :routing => 'wake' do
  text = "```Slack TicTacToe by Brandon\n\nThanks #{@current_player}! I\'m awake.\n\n/tictactoe [wake up] - Sometimes I sleep. Use this to wake me up!\n/tictactoe [status] - Display the current board and list whose turn it is.\n/tictactoe [challenge @username] - Challenge a buddy to a game.\n/tictactoe play <position>\n/tictactoe [positions] - Displays available board positions.\n/tictactoe [end] - Ends the active game in the channel.```"

  json = {
    text: text,
    response_type: 'in_channel',
    mrkdwn: true
  }

  @conn.post do |req|
    req.body = JSON.generate(json)
  end
end

post '/', :routing => 'positions' do
  text = "#{Game.new.represent(true)}"
  json = {
    text: text,
    response_type: 'in_channel',
  }

  @conn.post do |req|
    req.body = JSON.generate(json)
  end
end

post '/*' do
  'I don\'t recognize this command.'
end
