class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.string :playerX
      t.string :playerO
      t.string :channel_id
      t.string :game, array: true, default: Array.new(9)
      t.boolean :finished, default: false
    end
  end
end
