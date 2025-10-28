#!/bin/sh

# Run klayout to extract bondpad locations and geometries.  These are saved in two *.tex files and loaded by latex.
klayout -z -r ezbond_klayout.py ~/chips/demo-washakie/ic/tapeout_upload/washakie.ASIC_final.gds

# Run latex to generate the pdf of the chip outline with bond wires.  You may
# need to add Poseidon's latex distribution to your PATH variable.
#pdflatex ezbond.tex #
