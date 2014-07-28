#!/usr/bin/env ruby

system("make")

['sample', 'akabei', 'red', 'prod'].each do |g|
#['akabei', 'red', 'prod'].each do |g|
  ['world-1', 'world-2', 'world-classic'].each do |m|
    if g == 'prod'
      ghc = 'akabei.ghc pinky1.ghc pinky2.ghc pinky3.ghc'
    elsif g == 'red'
      ghc = 'akabei.ghc pinky3.ghc pinky1.ghc akabei.ghc'
    else
      ghc = "#{g}.ghc"
    end
    name = "#{m}-#{g}"
    log = "logs/#{name}.log"
    if !system("go run sim.go maps/#{m}.map lambdaman.gcc #{ghc} > #{log}")
      raise
    end

    result = `grep Lives #{log} | tail -1`
    puts "#{name} #{result}"
  end
end
