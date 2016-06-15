class Game < ActiveRecord::Base

  #prevents multiple games being played in same channel
  validates_uniqueness_of :channel_id,
    :scope => :finished,
    :message => "already has a game in progress!",
    conditions: -> { where(finished: false) }

  # Constants
  WIN_COMBINATIONS = [
    [0,1,2], #top row
    [3,4,5], #mid row
    [6,7,8], #low row
    [0,3,6], #left v
    [1,4,7], #mid v
    [2,5,8], #rite v
    [0,4,8], #diag1
    [2,4,6] #diag2
  ]

  def represent(bool = false)
    self.game = Array.new([*1..9]) if bool
    board = self.game
    str =  "•           •\n"
    str += " #{board[0] || "   "} | #{board[1] || "   "} | #{board[2] || "   "} \n"
    str += "----------\n"
    str += " #{board[3] || "   "} | #{board[4] || "   "} | #{board[5] || "   "} \n"
    str += "----------\n"
    str += " #{board[6] || "   "} | #{board[7] || "   "} | #{board[8] || "   "} \n"
    str +=  "•           •\n"
    return str
  end

  def won?
    if self.game.all?{ |position| position == nil }
      false
    elsif
      WIN_COMBINATIONS.each do |combo|
        plays = [self.game[combo[0]],self.game[combo[1]],self.game[combo[2]]]
        if (plays == ["X","X","X"]) || (plays == ["O","O","O"])
          team = self.game[combo[0]]
          return {player: self["player#{team}"], team: team, combo: combo}
        else
          false
        end
      end
    else
      true
    end
  end

  def full?
    self.game.none?{ |position| position == nil }
  end

  def draw?
    full? && !won?
  end

  def finished?
    won? || draw? || full?
  end

  def turn_count
    count = 0
    self.game.each do |position|
      if position == "X" || position == "O"
        count += 1
      end
    end
    return count
  end

  def current_player
    turn_count.even? ? {player: self.playerX, move: "X"} : {player: self.playerO, move: "O"}
  end

  def valid_move?(position)
    position = position.to_i
    position.between?(1,9) && (self.game[position - 1] == nil)
  end

  def self.games_finished_in_channel?(channel_id)
    if self.where(finished: false).where(channel_id: channel_id).size != 0
      return false
    else
      return true
    end
  end

end
