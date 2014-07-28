require './lman'

class Lman
  def gen
    ldc(21)
    ldf(:body)
    ap(1)
    rtn()
    label(:body)
    ld(0, 0)
    ld(0, 0)
    add()
    rtn()

    emit
  end
end

L.gen
