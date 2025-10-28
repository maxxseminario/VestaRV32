echo off
set basename="bench"
python image2blackwhite.py %basename%.jpg %basename%.bw.png 230
python png2cif.py %basename%.bw.png %basename% 2000 "L39D60" %basename%.cif
python logo_drc_check.py %basename%.bw.png %basename%.drc.png
echo "Open the CIF file in Klayout (edit mode)"
echo "Then, select Edit->Layer->Merge, set both layer drop downs to 39/60 (the Mu, or M9, layer purpose pair), and click OK"
echo "Save the file as a GDS file with format as GDS2, database unit as 0.001 um, and library myshkin"
echo "Stream into Virtuoso"