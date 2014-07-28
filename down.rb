require './lman'

class Lman
  def gen
    dum(2)
    ldc(2)
    ldf(:step)
    ldf(:init)
    rap(2)
    rtn()

    label(:init)
    ldc(42)
    ld(0, 1)
    cons()
    rtn()

    label(:step)
    ld(0, 0)
    ldc(1)
    add()
    ld(1, 0)
    cons()
    rtn()

    emit
  end
end

L.gen
