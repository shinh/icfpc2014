c = $<.read.gsub("\n", '')

puts "total: #{c.size}"
puts "wall: #{c.count('#')} #{c.count('#') * 100 / c.size}%"
puts "pill: #{c.count('.')} #{c.count('.') * 100 / c.size}%"

