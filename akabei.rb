#!/usr/bin/env ruby

require './ghost.rb'

adj = ARGV[0].to_i

DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]]

in_danger = [60]

G.mov in_danger, 0

diff_table_imm = 70
4.times do |d|
  G.mov [diff_table_imm + d], DIRS[d][0] % 256
  G.mov [diff_table_imm + d + 4], DIRS[d][1] % 256
end

G.get_id
G.get_pos
gx = [40]
gy = [41]
G.mov gx, A
G.mov gy, B

G.get_lpos
lx = [50]
ly = [51]
G.mov lx, A
G.mov ly, B

G.label :calc_dist
dist = [55]

G.jgt :gx_is_larger, gx, lx
G.mov D, lx
G.sub D, gx
G.jmp :x_compare_done

G.label :gx_is_larger
G.mov D, gx
G.sub D, lx

G.label :x_compare_done
G.mov dist, D

G.jgt :gy_is_larger, gy, ly
G.mov D, ly
G.sub D, gy
G.jmp :y_compare_done

G.label :gy_is_larger
G.mov D, gy
G.sub D, ly

G.label :y_compare_done
G.add dist, D

if adj > 0
  G.label(:predict)

  G.jgt :predict_done, D, adj == 3 ? 2 : 3

  prev_lx = [90]
  prev_ly = [91]
  G.jeq :predict_done, prev_lx, 0

  G.mov C, lx
  G.sub C, prev_lx
  G.mul C, adj
  G.mov D, ly
  G.sub D, prev_ly
  G.mul D, adj

  G.add lx, C
  G.add ly, D

  G.label(:predict_done)
  G.mov prev_lx, A
  G.mov prev_ly, B

  G.get_id
end

# dx = [30]
# dy = [31]
# G.mov dx, lx
# G.mov dy, ly
# G.sub dx, A
# G.sub dy, B

p0_imm = 20
p0 = [p0_imm]
p1 = [p0_imm + 1]
p2 = [p0_imm + 2]
p3 = [p0_imm + 3]

G.jlt :neg_dy, ly, gy

G.jgt :pos_dy_pos_dx, lx, gx

# ly>gy && lx<gx
G.mov A, gx
G.sub A, lx
G.mov B, ly
G.sub B, gy
G.jlt :pos_dy_neg_dx_x, B, A

G.mov p0, 2
G.mov p1, 3
G.mov p2, 1
G.mov p3, 0
G.jmp(:got_priority)

G.label(:pos_dy_neg_dx_x)
G.mov p0, 3
G.mov p1, 2
G.mov p2, 0
G.mov p3, 1
G.jmp(:got_priority)

# ly>gy && lx>gx
G.label(:pos_dy_pos_dx)
G.mov A, lx
G.sub A, gx
G.mov B, ly
G.sub B, gy
G.jlt :pos_dy_pos_dx_x, B, A

G.mov p0, 2
G.mov p1, 1
G.mov p2, 3
G.mov p3, 0
G.jmp(:got_priority)

G.label(:pos_dy_pos_dx_x)
G.mov p0, 1
G.mov p1, 2
G.mov p2, 0
G.mov p3, 3
G.jmp(:got_priority)

G.label(:neg_dy)

G.jgt :neg_dy_pos_dx, lx, gx

# ly<gy && lx<gx
G.mov A, gx
G.sub A, lx
G.mov B, gy
G.sub B, ly
G.jlt :neg_dy_neg_dx_y, A, B

G.mov p0, 3
G.mov p1, 0
G.mov p2, 2
G.mov p3, 1
G.jmp(:got_priority)

G.label(:neg_dy_neg_dx_y)
G.mov p0, 0
G.mov p1, 3
G.mov p2, 1
G.mov p3, 2
G.jmp(:got_priority)

# ly<gy && lx>gx
G.label(:neg_dy_pos_dx)
G.mov A, lx
G.sub A, gx
G.mov B, gy
G.sub B, ly
G.jlt :neg_dy_pos_dx_y, A, B

G.mov p0, 1
G.mov p1, 0
G.mov p2, 2
G.mov p3, 3
G.jmp(:got_priority)

G.label(:neg_dy_pos_dx_y)
G.mov p0, 0
G.mov p1, 1
G.mov p2, 3
G.mov p3, 2
G.jmp(:got_priority)

G.label(:got_priority)

G.label :search_ppill
PPILL_W = 4
x = [56]
y = [57]
G.mov y, 256 - PPILL_W

G.label :search_ppill_y_loop

G.mov B, y
G.add B, ly

G.mov x, 256 - PPILL_W

G.label :search_ppill_x_loop

G.mov A, x
G.add A, lx

G.get_map

G.jeq :reverse, A, 3

G.add x, 1
G.jeq :search_ppill_x_loop_done, x, PPILL_W + 1
G.jmp :search_ppill_x_loop

G.label :search_ppill_x_loop_done

G.add y, 1
G.jeq :search_ppill_done, y, PPILL_W + 1
G.jmp :search_ppill_y_loop

G.label :search_ppill_done

G.get_id
G.get_stat
G.and A, 1
G.jeq :shuffle, A, 0

G.label :reverse

G.jgt :shuffle, dist, 10

G.mov in_danger, 1

G.mov A, p0
G.mov p0, p3
G.mov p3, A
G.mov A, p1
G.mov p1, p2
G.mov p2, A

# # Dump priorities
# G.mov A, p0
# G.mov B, p1
# G.mov C, p2
# G.mov D, p3
# G.dbg

G.label :shuffle
if true
  G.get_id
  G.add [80], A
  G.add [80], 7
  G.mul [80], 13

  G.jeq :shuffle_done, in_danger, 1

  G.jlt :shuffle_done, dist, 2

  G.jgt :shuffle_done, [80], 10

  G.dbg

  G.add [81], A
  G.add [81], 37
  G.mul [81], 97
  G.mov A, [80]
  G.mov B, [81]
  G.div A, 64
  G.div B, 64
  G.add A, p0_imm
  G.add B, p0_imm
  G.mov C, [A]
  G.mov [A], [B]
  G.mov [B], C
end
G.label(:shuffle_done)

4.times do |d|
  # The direction.
  G.mov D, [p0_imm + d]

  G.get_id
  G.get_stat
  G.add B, 2
  G.and B, 3
  #G.dbg
  G.jeq :"invalid_#{d}", B, D

  G.mov A, gx
  G.mov C, diff_table_imm
  G.add C, D
  G.add A, [C]

  G.mov B, gy
  G.add C, 4
  G.add B, [C]

  #G.dbg
  G.get_map

  G.jgt :done, A, 0

  G.label :"invalid_#{d}"

  #G.dbg
end

G.label(:done)
G.mov A, D
G.set_dir

G.mov G, 230
G.label :loop
G.sub [G], [253]
G.add G, 1
G.mul [G], [3]
G.add A, [G]
G.mul [G], [7]
G.add B, [G]
G.get_map
G.jlt :loop, G, 250

G.hlt

G.emit
