#!/usr/bin/ruby

require 'json'

def shut_down
  puts "\nShutting down gracefully..."
  $pids.each do |pid|
    Process.kill("INT", pid)
  end

  exit 0
end

# Trap ^C 
Signal.trap("INT") { 
  shut_down 
  exit
}

# Trap `Kill `
Signal.trap("TERM") {
  shut_down
  exit
}

config = JSON.load(File.open("./watchdog.json", 'r'))
threads = []
$pids = []

config["shards"].times do |shard|
  # find abstract way to spawn these so we can still kill them safely
  threads << Thread.new do
    pid = Process.spawn({ "SHARD" => shard.to_s, "TOTALSHARDS" => config["shards"].to_s }, "ruby ../ghost/bot.rb", [:out, :err]=>["logs/log_shard" + shard.to_s, "w"])
    $pids.push pid
    Process.wait(pid)
  end
end

threads.each(&:join)
