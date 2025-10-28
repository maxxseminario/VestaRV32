#!/bin/sh

# Run klayout to extract bondpad locations and geometries.  These are saved in two *.tex files and loaded by latex.
klayout -z -r ezbond_klayout.py /home/mseminario2/chips/myshkin/latex/bonding-diagram/M16832.gds

# Run latex to generate the pdf of the chip outline with bond wires.  You may
# need to add Poseidon's latex distribution to your PATH variable.
#pdflatex ezbond.tex #
