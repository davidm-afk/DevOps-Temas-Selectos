with open("SanchezGalvan_DavidMoroni_T1_Contenedores.pdf", "rb") as f:
    data = f.read()

import re
print("PDF header:", data[:100])
# Look for /Producer, /Creator, /Title, /Author
metadata = re.findall(rb"/([A-Z][a-zA-Z]+)\s*(\([^)]+\)|<[^>]+>)", data)
print("Metadata fields:")
for k, v in metadata[:15]:
    print(" ", k.decode('ascii', errors='ignore'), "->", v[:50])

# Check for font names
fonts = re.findall(rb"/BaseFont\s*/([A-Za-z0-9+-]+)", data)
print("Fonts:", set([f.decode('ascii', errors='ignore') for f in fonts]))

# Check if FlateDecode is used
print("FlateDecode occurrences:", len(re.findall(rb"/FlateDecode", data)))
print("DCTDecode (JPEG) occurrences:", len(re.findall(rb"/DCTDecode", data)))
print("JPXDecode (JPEG2000):", len(re.findall(rb"/JPXDecode", data)))
