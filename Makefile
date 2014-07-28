GHCS := akabei.ghc pinky1.ghc pinky2.ghc pinky3.ghc

all: lman_inst.rb ghost_inst.rb lambdaman.gcc $(GHCS)

lambdaman.gcc: ai.rb lman_inst.rb dsl.rb lman.rb
	ruby $< > $@.tmp && mv $@.tmp $@

akabei.ghc: akabei.rb ghost_inst.rb ghost.rb
	ruby $< > $@.tmp && mv $@.tmp $@

pinky1.ghc: akabei.rb ghost_inst.rb ghost.rb
	ruby $< 1 > $@.tmp && mv $@.tmp $@

pinky2.ghc: akabei.rb ghost_inst.rb ghost.rb
	ruby $< 2 > $@.tmp && mv $@.tmp $@

pinky3.ghc: akabei.rb ghost_inst.rb ghost.rb
	ruby $< 3 > $@.tmp && mv $@.tmp $@

lman_inst.rb: gen_lman_inst.rb
	ruby $< > $@.tmp && mv $@.tmp $@

ghost_inst.rb: gen_ghost_inst.rb
	ruby $< > $@.tmp && mv $@.tmp $@



