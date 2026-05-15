#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)

mkdir -p "$TMP/META-INF" "$TMP/OEBPS"

printf 'application/epub+zip' > "$TMP/mimetype"

cat > "$TMP/META-INF/container.xml" << 'EOF'
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
      media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
EOF

cat > "$TMP/OEBPS/content.opf" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf"
  unique-identifier="bookid" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:identifier id="bookid">test-epub-001</dc:identifier>
  </metadata>
  <manifest>
    <item id="ch1" href="chapter1.xhtml"
      media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml"
      media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx"
      media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
EOF

cat > "$TMP/OEBPS/toc.ncx" << 'EOF'
<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
      <navPoint id="np1-1" playOrder="2">
        <navLabel><text>Section 1.1</text></navLabel>
        <content src="chapter1.xhtml#section-1-1"/>
      </navPoint>
      <navPoint id="np1-2" playOrder="3">
        <navLabel><text>Section 1.2</text></navLabel>
        <content src="chapter1.xhtml#section-1-2"/>
      </navPoint>
    </navPoint>
    <navPoint id="np2" playOrder="4">
      <navLabel><text>Chapter 2</text></navLabel>
      <content src="chapter2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
EOF

cat > "$TMP/OEBPS/chapter1.xhtml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body>
  <h1 id="chapter-1">Chapter 1</h1>
  <p>Hello from chapter one.</p>
  <p><a href="https://example.com">External Link</a></p>
  <h2 id="section-1-1">Section 1.1</h2>
  <p>Content of section 1.1.</p>
  <h2 id="section-1-2">Section 1.2</h2>
  <p>Content of section 1.2.</p>
</body>
</html>
EOF

cat > "$TMP/OEBPS/chapter2.xhtml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 2</title></head>
<body><h1>Chapter 2</h1><p>Hello from chapter two.</p></body>
</html>
EOF

cd "$TMP"
zip -X "$DIR/minimal.epub" mimetype
zip -rg "$DIR/minimal.epub" META-INF OEBPS
cd - > /dev/null
rm -rf "$TMP"
echo "Created: $DIR/minimal.epub"
