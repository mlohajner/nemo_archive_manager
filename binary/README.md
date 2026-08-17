# Binaries

This directory contains prebuilt binary of Nemo with:
- gallery_patch
- bandwidth graph patch
- self patch
- nemo icon

<img src="Ultimate.png" width="70%">

These binaries are provided for *Fedora users* who prefer not to compile the source code manually.
No installation needed, backup your current /usr/bin/nemo and replace with provided executable

**NOTE:  
To use GSettings sheme -persistence and additional custimisations, compile and install: `org.nemo.transfer-graph.gschema.xml`**
```
sudo cp org.nemo.transfer-graph.gschema.xml /usr/share/glib-2.0/schemas/
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/
```

They are intended for convenience and quick testing of the feature.

⚠️ Use at your own discretion and ensure you trust the provided builds before installing.
