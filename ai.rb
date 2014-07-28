#!/usr/bin/env ruby

require './dsl'

DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]]

SCORE_SYMS = %i(score_u score_r score_d score_l)

SCORE_MAX_PARAM = 300000

SAFE_VIT_PARAM = 400

NEVER_TOUCH_PILLMAP_LIMIT = 30000

PILLMAP_LIMIT = 10000

DIR_SCORE_DIST = 50
#DIR_SCORE_DIST = 50
#DIR_SCORE_DIST = 10

SUBMAP_SIZE = 10

def ret_step(s)
  st(:ai_state, tuple(:map_size, cons(:pill_map, :pill_num),
                      :waiting, :game_score))
  ret(cons(:ai_state, s))
end

def map_each(map, &proc)
  whileP(atom(map) == 0) do
    st(:row, car(map))
    st(map, cdr(map))
    whileP(atom(:row) == 0) do
      st(:cell, car(:row))
      st(:row, cdr(:row))
      instance_eval(&proc)
    end
  end
end

def map_each_pos(map, &proc)
  st(:y, 0)
  whileP(atom(map) == 0) do
    st(:x, 0)
    st(:row, car(map))
    st(map, cdr(map))
    whileP(atom(:row) == 0) do
      st(:cell, car(:row))
      st(:row, cdr(:row))
      instance_eval(&proc)
      inc(:x, 1)
    end
    inc(:y, 1)
  end
end

Func.new(:main, :state, :undocumented) do
  st(:map, ld(:state)[0])

  st(:map_size, call(:getMapSize, :map))
  st(:pill_map, call(:getPillMap, :map))

  st(:ai_state, tuple(:map_size, :pill_map, 0, 0))
  #dbg(:ai_state)

  ret(cons(:ai_state, ldf(:step)))
end

Func.new(:getPillMap, :map) do
  st(:pills, 0)
  st(:pill_num, 0)
  map_each_pos(:map) do
    ifP((ld(:cell) > 1) * (ld(5) > :cell)) do
      st(:pills, cons(cons(cons(:x, :y), :cell), :pills))
      inc(:pill_num, 1)
    end
  end
  ret(cons(:pills, :pill_num))
end

Func.new(:getMapSize, :map) do
  st(:size, 0)
  map_each(:map) do
    inc(:size, 1)
  end
  ret(:size)
end

Func.new(:step, :ai_state, :state) do
  ret(call(:step_fast, :ai_state, :state))
end

def step_prologue
  st(:map, ld(:state)[0])
  st(:lman, ld(:state)[1])
  st(:lvit, ld(:lman)[0])
  st(:lpos, ld(:lman)[1])
  st(:ldir, ld(:lman)[2])
  st(:game_score, ld(:lman).at(4, 5))
  st(:ghosts, ld(:state)[2])
  st(:fruit, cdr(cdr(cdr(ld(:state)))))
  st(:lx, car(:lpos))
  st(:ly, cdr(:lpos))
  st(:worth_cell, 4)
  if_(:fruit, st(:worth_cell, 5))

  st(:map_size, ld(:ai_state).at(0, 4))
  st(:pill_map, car(ld(:ai_state).at(1, 4)))
  st(:pill_num, cdr(ld(:ai_state).at(1, 4)))
  st(:waiting, ld(:ai_state).at(2, 4))
  st(:prev_game_score, ld(:ai_state).at(3, 4))

  inc(:waiting, -1)
  ifP(ldc(0) > :waiting) do
    st(:waiting, 0)
  end

  st(:eating, ld(:game_score) - :prev_game_score)

  comment('Update pill map start')
  st(:pills, 0)
  #st(:pill_num, 0)

  ifP(ldc(PILLMAP_LIMIT) > ld(:pill_num)) do
    whileP(atom(:pill_map) == 0) do
      st(:pill, car(:pill_map))
      st(:pos, car(:pill))
      st(:pill_map, cdr(:pill_map))
      ifelse_((car(:pos) == :lx) * (cdr(:pos) == :ly),
              inc(:pill_num, -1),
              st(:pills, cons(:pill, :pills)))
    end
    st(:pill_map, :pills)
  end

  comment('Update pill map done')

  #dbg(:ai_state)
end

Func.new(:getSubWall) do
  width = SUBMAP_SIZE * 2 + 3
  st(:cnt, width)
  st(:row, 0)
  whileP(:cnt) do
    st(:row, cons(0, :row))
    inc(:cnt, -1)
  end
  ret(:row)
end

Func.new(:getSubMap, :map, :lx, :ly) do
  st(:rmap, 0)

  st(:y, -1)
  whileP(expr(inc(:y, 1), atom(:map) == 0)) do
    st(:x, -1)
    st(:row, car(:map))
    st(:map, cdr(:map))
    st(:rrow, 0)

    st(:dy, ld(:y) - :ly)
    if_(ldc(-SUBMAP_SIZE) > ld(:dy), next_)
    if_(ld(:dy) > SUBMAP_SIZE, break_)

    whileP(expr(inc(:x, 1), atom(:row) == 0)) do
      st(:cell, car(:row))
      st(:row, cdr(:row))

      st(:dx, ld(:x) - :lx)
      if_(ldc(-SUBMAP_SIZE) > ld(:dx), next_)
      if_(ld(:dx) > SUBMAP_SIZE, break_)

      #if_(ld(:dx) == 0, if_(ld(:dy) == 0, st(:cell, 999)))

      st(:rrow, cons(:cell, :rrow))
    end

    st(:rmap, cons(:rrow, :rmap))
  end

  st(:sub_map, 0)
  st(:sub_map, cons(call(:getSubWall), :sub_map))

  whileP(atom(:rmap) == 0) do
    #dbg(:sub_map)

    st(:rrow, car(:rmap))
    st(:rmap, cdr(:rmap))
    st(:row, 0)

    st(:row, cons(0, :row))

    whileP(atom(:rrow) == 0) do
      st(:cell, car(:rrow))
      st(:rrow, cdr(:rrow))

      st(:row, cons(:cell, :row))
    end

    st(:row, cons(0, :row))

    st(:sub_map, cons(:row, :sub_map))
  end

  st(:sub_map, cons(call(:getSubWall), :sub_map))

  ret(:sub_map)
end

def get_abs(s)
  if_(ldc(0) > s, st(s, ldc(0) - s))
end

Func.new(:getOppDir, :dir) do
  if_(ld(:dir) == 0, ret(2))
  if_(ld(:dir) == 1, ret(3))
  if_(ld(:dir) == 2, ret(0))
  if_(ld(:dir) == 3, ret(1))
  hlt
end

def get_dir_score_prologue
  st(:lodir, call(:getOppDir, :ldir))
  SCORE_SYMS.each_with_index do |sym, i|
    st(sym, 0)
    ifP(call(:getXY, :map, ld(:lx) + DIRS[i][0], ld(:ly) + DIRS[i][1]) == 0) do
      st(sym, SCORE_MAX_PARAM * -3)
    end
    ifP(ld(:lodir) == i) do
      ifP(ld(:eating) == 0) do
        #inc(sym, -SCORE_MAX_PARAM)
        inc(sym, -SCORE_MAX_PARAM / 5)
        #inc(sym, -SCORE_MAX_PARAM / 10)
      end
    end
    ifP(ld(:best_move) == i) do
      #inc(sym, SCORE_MAX_PARAM / 10)
      ifelse_(:going_to_fruit,
              inc(sym, SCORE_MAX_PARAM * 3 / 2),
              inc(sym, SCORE_MAX_PARAM / 3))
    end

    ifP(ld(:lvit) > ldc(SAFE_VIT_PARAM)) do
      st(:lnpos, call(:getMoved, cons(:lx, :ly), i))
      st(:ghost_iter, :ghosts)
      whileP(atom(:ghost_iter) == 0) do
        st(:ghost, car(:ghost_iter))
        st(:ghost_iter, cdr(:ghost_iter))
        st(:gvit, ld(:ghost)[0])
        st(:gpos, ld(:ghost)[1])
        st(:gdir, cdr(cdr(ld(:ghost))))

        ifP(ld(:gvit) == 1) do
          ifP(ldc(2) >= call(:getDist, :lnpos, :gpos)) do
            inc(sym, SCORE_MAX_PARAM * 2)
          end
          st(:gnpos, call(:getMoved, :gpos, :gdir))
          ifP(ldc(2) >= call(:getDist, :lnpos, :gnpos)) do
            #dbg(tuple(424243, i, :lnpos, :gnpos))
            inc(sym, SCORE_MAX_PARAM * 2)
          end

          ifP(car(:lnpos) == car(:gpos)) do
            ifP(cdr(:lnpos) == cdr(:gpos)) do
              inc(sym, SCORE_MAX_PARAM * 20)
            end
          end

          ifP(car(:lnpos) == car(:gnpos)) do
            ifP(cdr(:lnpos) == cdr(:gnpos)) do
              inc(sym, SCORE_MAX_PARAM * 10)
            end
          end

        end
      end
    end

    ifP(ldc(SAFE_VIT_PARAM) > ld(:lvit)) do
      st(:lnpos, call(:getMoved, cons(:lx, :ly), i))
      st(:ghost_iter, :ghosts)
      whileP(atom(:ghost_iter) == 0) do
        st(:ghost, car(:ghost_iter))
        st(:ghost_iter, cdr(:ghost_iter))
        st(:gpos, ld(:ghost)[1])
        st(:gdir, cdr(cdr(ld(:ghost))))
        st(:gnpos, call(:getMoved, :gpos, :gdir))

        st(:dx, car(:gnpos) - car(:lnpos))
        st(:dy, cdr(:gnpos) - cdr(:lnpos))

        get_dir_score_core do |sym|
          st(sym, ld(sym) - ldc(SCORE_MAX_PARAM) / :d / :d)
          #st(sym, ld(sym) - ldc(SCORE_MAX_PARAM) / :d)
        end

      end
    end

  end
end

def get_dir_score_core(&calc_score)
  SCORE_SYMS.each_with_index do |sym, i|
    if i == 0
      st(:pd, ldc(0) - :dy)
    elsif i == 1
      st(:pd, :dx)
    elsif i == 2
      st(:pd, :dy)
    elsif i == 3
      st(:pd, ldc(0) - :dx)
    else
      raise
    end

    ifP(ld(:pd) > 0) do
      if i == 0 || i == 2
        st(:sd, :dx)
      elsif i == 1 || i == 3
        st(:sd, :dy)
      else
        raise
      end

      get_abs(:sd)

      ifP(ld(:pd) >= (:sd)) do
        st(:d, ld(:sd) + :pd)

        calc_score[sym]
      end

    end

  end
  nil
end

Func.new(:getDirScores, :map, :lx, :ly, :ldir, :worth_cell, :best_move,
         :lvit, :ghosts, :eating, :going_to_fruit) do
  get_dir_score_prologue

  st(:y, -1)
  whileP(expr(inc(:y, 1), atom(:map) == 0)) do
    st(:x, -1)
    st(:row, car(:map))
    st(:map, cdr(:map))

    st(:dy, ld(:y) - :ly)
    if_(ldc(-DIR_SCORE_DIST) > ld(:dy), next_)
    if_(ld(:dy) > DIR_SCORE_DIST, break_)

    whileP(expr(inc(:x, 1), atom(:row) == 0)) do
      st(:cell, car(:row))
      st(:row, cdr(:row))

      st(:dx, ld(:x) - :lx)
      if_(ldc(-DIR_SCORE_DIST) > ld(:dx), next_)
      if_(ld(:dx) > DIR_SCORE_DIST, break_)

      ifP((ld(:cell) > 1) * (ld(:worth_cell) > :cell)) do
        #dbg(cons(:x, :y))

        get_dir_score_core do |sym|
          st(sym, ld(sym) + ldc(SCORE_MAX_PARAM) / :d / :d)
        end
      end
    end
  end

  ret(tuple(:score_u, :score_r, :score_d, :score_l))
end

Func.new(:getDirScores2, :map, :lx, :ly, :ldir,
         :worth_cell, :pill_map, :best_move,
         :lvit, :ghosts, :eating, :going_to_fruit) do
  get_dir_score_prologue

  whileP(atom(:pill_map) == 0) do
    st(:pill, car(:pill_map))
    st(:x, car(car(:pill)))
    st(:y, cdr(car(:pill)))
    st(:cell, cdr(:pill))
    st(:pill_map, cdr(:pill_map))

    if_(ld(:worth_cell) == :cell, next_)

    st(:dy, ld(:y) - :ly)
    st(:dx, ld(:x) - :lx)

    get_dir_score_core do |sym|
      st(sym, ld(sym) + ldc(SCORE_MAX_PARAM) / :d / :d)
    end
  end

  ret(tuple(:score_u, :score_r, :score_d, :score_l))
end

Func.new(:step_fast, :ai_state, :state) do
  step_prologue

  comment('Call getSubMap')

  st(:sub_map, call(:getSubMap, :map, :lx, :ly))
  #dbg(:sub_map)
  st(:dist, call(:getInitDistMap, :sub_map))
  st(:cx, SUBMAP_SIZE + 1)
  st(:cy, SUBMAP_SIZE + 1)
  ifP(ldc(SUBMAP_SIZE) > :lx) do
    st(:cx, ld(:lx) + 1)
  end
  ifP(ldc(SUBMAP_SIZE) > :ly) do
    st(:cy, ld(:ly) + 1)
  end
  st(:cpos, cons(:cx, :cy))
  st(:adj, cons(ld(:cx) - :lx, ld(:cy) - :ly))

  st(:dist, call(:fillDistMap, :sub_map, :dist, :cpos))
  #st(:sub_map, call(:setXY, :sub_map, SUBMAP_SIZE + 1, SUBMAP_SIZE + 1, 777))
  #dbg(:sub_map)
  #dbg(:dist)
  st(:best_move, call(:getBestMove, :sub_map, :dist, :worth_cell,
                      1, 1, 1, 1))
  st(:going_to_fruit, cdr(:best_move) == -1)
  st(:best_move, car(:best_move))

  #st(:dir_scores, call(:getDirScores, :map, :lx, :ly, :ldir, :worth_cell))
  ifelse_(ldc(PILLMAP_LIMIT) > ld(:pill_num),
          st(:dir_scores, call(:getDirScores2, :map, :lx, :ly, :ldir,
                               :worth_cell, :pill_map, :best_move,
                               :lvit, :ghosts, :eating, :going_to_fruit)),
          st(:dir_scores, call(:getDirScores, :map, :lx, :ly, :ldir,
                               :worth_cell, :best_move,
                               :lvit, :ghosts, :eating, :going_to_fruit)))

  dbg(tuple(:map_size, :pill_num, :dir_scores, :waiting, :eating))

  ifP(ldc(SAFE_VIT_PARAM) > :lvit) do
    st(:best_move, -1)
    st(:best_score, SCORE_MAX_PARAM * -4)
    %i(ok_u ok_r ok_d ok_l).each_with_index do |ok, i|
      st(ok, call(:isOK_d, :map, :lpos, i, (i + 2) % 4, :ghosts, :dist, :adj))

      ifP(ld(ok) == 2) do
        inc(:waiting, 3)
        ifP(ldc(1000) > ld(:fruit)) do
          ifP(ldc(200) > :waiting) do
            DIRS.each_with_index do |dir, i|
              ifP(call(:getXY, :map,
                       ld(:lx) + dir[0], ld(:ly) + dir[1]) == 0) do
                ret_step(i)
              end
            end

            st(ok, 0)
          end
        end
      end

      ifP(ok) do
        st(:score, ld(:dir_scores).at(i, 4))
        ifP(ld(:score) > :best_score) do
          st(:best_score, :score)
          st(:best_move, i)
        end
      end
    end
    ifP(ld(:best_move) >= 0) do
      ret_step(:best_move)
    end
  end

  %i(ok_u ok_r ok_d ok_l).each_with_index do |ok, i|
    st(:score, ld(:dir_scores).at(i, 4))
    ifP(ld(:score) > :best_score) do
      st(:best_score, :score)
      st(:best_move, i)
    end
  end
  ifP(ld(:best_move) >= 0) do
    ret_step(:best_move)
  end

  dbg(-999)
  ret_step(2)
end

Func.new(:step_slow, :ai_state, :state) do
  step_prologue

  #st(:x, :lx)
  #st(:y, :ly)
  #dbg(cons(:lx, :ly))
  #dbg(cons(:x, :y))
  #dbg(ld(:move) == 0)

  st(:dist, call(:getInitDistMap, :map))
  st(:dist, call(:fillDistMap, :map, :dist, :lpos))
  #st(:dist, call(:setXY, :dist, 1, 1, 42))
  #dbg(:dist)

  ifP(ldc(SAFE_VIT_PARAM) > :lvit) do
    %i(ok_u ok_r ok_d ok_l).each_with_index do |ok, i|
      st(ok, call(:isOK, :map, :lpos, i, (i + 2) % 4, :ghosts))
    end

    st(:best_move, car(call(:getBestMove, :map, :dist, :worth_cell,
                            :ok_u, :ok_r, :ok_d, :ok_l)))
    ifP(ld(:best_move) >= 0) do
      dbg(cons(list(:ok_u, :ok_r, :ok_d, :ok_l), :best_move))
      ret_step(:best_move)
    end

    ifP(ldc(4) > ld(:ok_u) + :ok_r + :ok_d + :ok_l) do
      %i(ok_u ok_r ok_d ok_l).each_with_index do |ok, i|
        ifP(ok) do
          ifP(call(:getXY, :map,
                   ld(:lx) + DIRS[i][0], ld(:ly) + DIRS[i][1])) do
            dbg(cons(i, list(:ok_u, :ok_r, :ok_d, :ok_l)))
            ret_step(i)
          end
        end
      end
      nil
    end

    dbg(list(:ok_u, :ok_r, :ok_d, :ok_l))
  end

  st(:best_move, car(call(:getBestMove, :map, :dist, :worth_cell,
                          1, 1, 1, 1)))
  dbg(cons(:lvit, :best_move))

  st(:move, :best_move)

  # whileP(exprP{
  #          st(:x, :lx)
  #          st(:y, :ly)
  #          if_(ld(:move) == 0, st(:y, ld(:y) - 1))
  #          if_(ld(:move) == 1, st(:x, ld(:x) + 1))
  #          if_(ld(:move) == 2, st(:y, ld(:y) + 1))
  #          if_(ld(:move) == 3, st(:x, ld(:x) - 1))
  #          call(:getXY, :map, :x, :y) == 0
  #        }) do
  #   st(:move, ld(:move) + 1)
  #   if_(ld(:move) == 4, st(:move, 0))
  # end

  #st(:a, 42)
  #st(:b, 43)
  #dbg(ld(:a) >= ld(:b))

  ret_step(:move)
end

Func.new(:getBestMove, :map, :dist, :worth_cell,
         :ok_u, :ok_r, :ok_d, :ok_l) do
  st(:y, 0)
  st(:best_dist, 9999999)
  st(:best_move, -1)
  whileP(atom(:dist) == 0) do
    st(:x, 0)
    st(:row, car(:dist))
    st(:dist, cdr(:dist))

    whileP(atom(:row) == 0) do
      st(:v, car(:row))
      st(:row, cdr(:row))

      st(:d, car(:v))
      ifP(ld(:d) > 0) do
        #dbg(list(:x, :y))
        st(:c, call(:getXY, :map, :x, :y))
        ifP((ld(:c) > 1) * (ld(:worth_cell) > :c)) do
          ifP(ld(:c) == 4) do
            dbg(tuple(49494949, :best_dist, cdr(:v)))
            st(:d, -1)
          end

          ifP(ld(:best_dist) > ld(:d)) do
            st(:move, cdr(:v))
            st(:ok, ((ld(:move) == 0) * :ok_u +
                     (ld(:move) == 1) * :ok_r +
                     (ld(:move) == 2) * :ok_d +
                     (ld(:move) == 3) * :ok_l))

            ifP(:ok) do
              st(:best_dist, :d)
              st(:best_move, cdr(:v))
            end
          end
        end
      end

      st(:x, ld(:x) + 1)
    end
    st(:y, ld(:y) + 1)
  end
  ret(cons(:best_move, :best_dist))
end

Func.new(:getXY, :map, :x, :y) do
  st(:v, ld(:map))
  while_(:y, do_(st(:y, ld(:y) - 1),
                 st(:v, cdr(:v))))
  st(:v, car(:v))
  while_(:x, do_(st(:x, ld(:x) - 1),
                 st(:v, cdr(:v))))
  ret(car(:v))
end

Func.new(:setXYRow, :row, :x, :v) do
  if_(:x, ret(cons(car(:row), call(:setXYRow, cdr(:row), ld(:x) - 1, :v))))
  ret(cons(:v, cdr(:row)))
end

Func.new(:setXY, :map, :x, :y, :v) do
  if_(:y, ret(cons(car(:map), call(:setXY, cdr(:map), :x, ld(:y) - 1, :v))))
  ret(cons(call(:setXYRow, car(:map), :x, :v), cdr(:map)))
end

Func.new(:fillDistMap, :map, :dist, :pos) do
  st(:x, car(:pos))
  st(:y, cdr(:pos))
  st(:dist, call(:setXY, :dist, :x, :y, cons(1, -1)))
  st(:tasks, list(cons(cons(:x, ld(:y) - 1), 0),
                  cons(cons(ld(:x) + 1, :y), 1),
                  cons(cons(:x, ld(:y) + 1), 2),
                  cons(cons(ld(:x) - 1, :y), 3)))

  #st(:limit, 0)
  #st(:cnt, 0)

  st(:d, 2)

  #whileP((atom(:tasks) == 0) * (ldc(10) > ld(:d))) do
  #whileP((atom(:tasks) == 0) * :limit) do
  whileP((atom(:tasks) == 0)) do
    st(:ntasks, 0)
    whileP(atom(:tasks) == 0) do
      #inc(:limit, -1)
      #inc(:cnt, 1)

      st(:task, car(:tasks))
      st(:tasks, cdr(:tasks))
      st(:pos, car(:task))
      st(:m, cdr(:task))
      st(:x, car(:pos))
      st(:y, cdr(:pos))

      #dbg(:pos)
      #dbg(:m)
      #dbg(car(call(:getXY, :dist, :x, :y)) == 0)

      ifP(car(call(:getXY, :dist, :x, :y)) == 0) do
        st(:dist, call(:setXY, :dist, :x, :y, cons(:d, :m)))
        st(:ntasks, cons(cons(cons(ld(:x) + 1, :y), :m), :ntasks))
        st(:ntasks, cons(cons(cons(ld(:x) - 1, :y), :m), :ntasks))
        st(:ntasks, cons(cons(cons(:x, ld(:y) + 1), :m), :ntasks))
        st(:ntasks, cons(cons(cons(:x, ld(:y) - 1), :m), :ntasks))
      end
    end

    st(:d, ld(:d) + 1)
    st(:tasks, :ntasks)
    #dbg(:d)
    #dbg(:dist)
    #dbg(:tasks)
  end

  #dbg(:cnt)

  ret(:dist)
end

Func.new(:getInitDistRow, :row) do
  if_(atom(:row), ret(0))
  st(:v, car(:row))
  if_(ld(:v) == 0, (st(:v, -1)))
  if_(ld(:v) > 0, (st(:v, 0)))
  ret(cons(cons(:v, -1), call(:getInitDistRow, cdr(:row))))
end

Func.new(:getInitDistMap, :map) do
  if_(atom(:map), ret(0))
  ret(cons(call(:getInitDistRow, car(:map)), call(:getInitDistMap, cdr(:map))))
end

Func.new(:getEmptyRow, :row) do
  if_(atom(:row), ret(0))
  ret(cons(0, call(:getEmptyRow, cdr(:row))))
end

Func.new(:getEmptyMap, :map) do
  if_(atom(:map), ret(0))
  ret(cons(call(:getEmptyRow, car(:map)), call(:getEmptyMap, cdr(:map))))
end

# The direction from :pos to :tpos.
Func.new(:getDir, :pos, :tpos) do
  ifP(car(:pos) == car(:tpos)) do
    ifP(cdr(:pos) > cdr(:tpos)) do
      ret(0)
    end
    ret(2)
  end
  ifP(cdr(:pos) == cdr(:tpos)) do
    ifP(car(:pos) > car(:tpos)) do
      ret(3)
    end
    ret(1)
  end
  ret(-1)
end

Func.new(:getDist, :pos, :tpos) do
  st(:dx, car(:pos) - car(:tpos))
  st(:dy, cdr(:pos) - cdr(:tpos))
  if_(ldc(0) > :dx, st(:dx, ldc(0) - :dx))
  if_(ldc(0) > :dy, st(:dy, ldc(0) - :dy))
  ret(ld(:dx) + :dy)
end

Func.new(:getMoved, :pos, :dir) do
  4.times do |i|
    ifP(ld(:dir) == i) do
      ret(cons(car(:pos) + DIRS[i][0], cdr(:pos) + DIRS[i][1]))
    end
  end
  hlt
end

Func.new(:isVisible, :map, :pos, :tpos, :dir) do
  #dbg(list(:pos, :tpos, :dir))
  whileP((car(:pos) == car(:tpos)) * (cdr(:pos) == cdr(:tpos)) == 0) do
    #dbg(:pos)
    ifP(call(:getXY, :map, car(:pos), cdr(:pos)) == 0) do
      #dbg(:pos)
      ret(0)
    end
    st(:pos, call(:getMoved, :pos, :dir))
  end
  ret(1)
end

Func.new(:isVisible_d, :map, :pos, :tpos, :dir) do
  #dbg(list(:pos, :tpos, :dir))
  whileP((car(:pos) == car(:tpos)) * (cdr(:pos) == cdr(:tpos)) == 0) do
    #dbg(:pos)
    ifP(call(:getXY, :map, car(:pos), cdr(:pos)) == 0) do
      #dbg(:pos)
      ret(0)
    end
    st(:pos, call(:getMoved, :pos, :dir))
  end
  ret(1)
end

def is_ok_impl(&check_ghost_dist)
  st(:lnpos, call(:getMoved, :lpos, :ldir))

  st(:cell, call(:getXY, :map, car(:lnpos), cdr(:lnpos)))
  st(:danger_ret, 0)
  ifP(ld(:cell) == 3) do
    st(:danger_ret, 1)
  end

  st(:min_gdist, 999)

  whileP(atom(:ghosts) == 0) do
    st(:ghost, car(:ghosts))
    st(:ghosts, cdr(:ghosts))
    st(:gpos, ld(:ghost)[1])
    st(:gdir, cdr(cdr(ld(:ghost))))

    ifP(ld(:lodir) == :gdir) do
      ifP(call(:getDir, :gpos, :lpos) == :gdir) do
        ifP(call(:isVisible, :map, :gpos, :lpos, :gdir)) do
          ret(:danger_ret)
        end
      end
    end

    st(:gdist, call(:getDist, :lnpos, :gpos))

    ifP(ld(:min_gdist) > :gdist) do
      st(:min_gdist, :gdist)
    end

    instance_eval(&check_ghost_dist)
  end

  ifP(ld(:cell) == 3) do
    #ifP(ld(:min_gdist) > 2) do
    ifP(ld(:min_gdist) > 1) do
      ret(2)
    end
  end

  ret(1)
end

Func.new(:isOK, :map, :lpos, :ldir, :lodir, :ghosts) do
  is_ok_impl do
    near_param = 2
    ifP(ldc(near_param) >= :gdist) do
      ret(:danger_ret)
    end
  end
end

Func.new(:isOK_d, :map, :lpos, :ldir, :lodir, :ghosts, :dist, :adj) do
  is_ok_impl do
    near_param = 2
    ifP(ldc(near_param) >= :gdist) do
      ifP(ldc(near_param + 2) >=
          car(call(:getXY, :dist,
                   car(:gpos) + car(:adj), cdr(:gpos) + cdr(:adj)))) do
        ret(:danger_ret)
      end
    end
    # st(:gnpos, call(:getMoved, :gpos, :gdir))
    # ifP(ldc(near_param) >= call(:getDist, :lnpos, :gnpos)) do
    #   ifP(ldc(near_param + 2) >=
    #       car(call(:getXY, :dist,
    #                car(:gnpos) + car(:adj), cdr(:gnpos) + cdr(:adj)))) do
    #     ret(0)
    #   end
    # end
  end
end

emit
