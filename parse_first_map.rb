#!/usr/bin/env ruby

$<.each do |line|
  if line =~ /^map\[(.*)\]$/
    tot = 0
    $1.split.map{|a|
      x, y = a.split(':')
      [y.to_i, x.to_i]
    }.sort.each do |cnt, pc|
      tot += cnt
      puts "#{pc}: #{cnt}"
    end

    p tot

    break
  end
end
