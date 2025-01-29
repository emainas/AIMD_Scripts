#!/bin/bash

for i in {1..10..1}; 
do
	cd frame${i}
	sbatch run.${i}.sh
	cd ..
done
