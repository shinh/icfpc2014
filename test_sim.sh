#!/bin/sh

go run sim.go maps/world-1.map ld.gcc sample.ghc > logs/1.log
go run sim.go maps/world-2.map ld.gcc sample.ghc > logs/2.log
go run sim.go maps/world-classic.map ld.gcc sample.ghc > logs/classic.log

grep Lives logs/1.log | tail -1 > actual.txt
grep Lives logs/2.log | tail -1 >> actual.txt
grep Lives logs/classic.log | tail -1 >> actual.txt

if diff golden.txt actual.txt; then
    echo 'PASS'
else
    echo 'FAIL'
fi
