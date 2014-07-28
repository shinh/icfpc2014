#!/usr/bin/env ruby

#W = 32
#H = 32
W = 256
H = 256
EMPTY = '.'

map = []

H.times{|y|
  r = ''
  W.times{|x|
    c = '#'
    if x == 0 || y == 0 || x == W - 1 || y == H - 1
      c = '#'
    elsif x % 2 == 1 || y % 2 == 1
      c = EMPTY
    end
    r += c
  }
  map << r
}

map[1][1] = '%'
map[W-83][H-83] = '\\'
map[H / 2 - 1][W / 2 - 1] = '='
map[H / 2 + 1][W / 2 - 1] = '='
map[H / 2 - 1][W / 2 + 1] = '='
map[H / 2 + 1][W / 2 + 1] = '='

map[W-5][H-5] = '.'

map = map * "\n"

while map.count('.') > 10000
  r = rand(map.size)
  if map[r] == '.'
    map[r] = ' '
  end
end

puts map
