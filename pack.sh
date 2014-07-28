#!/bin/sh

make

rm -fr shinh

mkdir -p shinh/solution
cp lambdaman.gcc shinh/solution
cp akabei.ghc shinh/solution/ghost0.ghc
cp pinky3.ghc shinh/solution/ghost1.ghc
cp pinky2.ghc shinh/solution/ghost2.ghc
cp pinky1.ghc shinh/solution/ghost3.ghc

cd shinh
svn export $SVN/icfpc/2014 code
chmod 755 code/ai.rb

cd ..
tar -cvzf shinh-icfpc2014.tgz shinh
sha1sum shinh-icfpc2014.tgz
