import zlib, re

with open("SanchezGalvan_DavidMoroni_T1_Contenedores.pdf", "rb") as f:
    data = f.read()

streams = re.findall(b"stream\r?\n(.*?)\r?\nendstream", data, re.DOTALL)
print("Streams:", len(streams))

# Check images vs text
images = re.findall(b"/Subtype\s*/Image", data)
print("Images count:", len(images))

extracted = []
for s in streams:
    try:
        decomp = zlib.decompress(s)
        # Find strings in parentheses
        pieces = re.findall(b"\(([^()]+)\)", decomp)
        for p in pieces:
            try:
                t = p.decode("utf-8")
                if any(c.isalnum() for c in t) and len(t) > 3:
                    extracted.append(t)
            except:
                try:
                    t = p.decode("latin1")
                    if any(c.isalnum() for c in t) and len(t) > 3:
                        extracted.append(t)
                except:
                    pass
    except Exception as e:
        pass

print("Extracted strings:", len(extracted))
for s in extracted[:60]:
    print("  *", s)
