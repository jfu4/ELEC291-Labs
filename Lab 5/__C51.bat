@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\Users\jerry\OneDrive\Documents\ELEC 291 Labs\Lab 5\"
"C:\Users\jerry\Downloads\CrossIDE\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\Users\jerry\OneDrive\Documents\ELEC 291 Labs\Lab 5\EFM8_ADC.c"
if not exist hex2mif.exe goto done
if exist EFM8_ADC.ihx hex2mif EFM8_ADC.ihx
if exist EFM8_ADC.hex hex2mif EFM8_ADC.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\Users\jerry\OneDrive\Documents\ELEC 291 Labs\Lab 5\EFM8_ADC.hex
