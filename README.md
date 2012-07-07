# FLAC2iPod CLI for OS X

## This isn't ready for use yet.

**Current status:** successfully adds MP3s to iPod, working on conversion now

This is a command line program that will accept either FLAC file(s) or a 
directory of FLACs as an argument, convert the FLAC(s) to MP3s, and load
the MP3s to a connected iPod or iPhone.

The loaded MP3s bypass the iTunes Library, and after syncing the MP3s
will be deleted.

##Running Requirements
- OS X Leopard or later
- iTunes must be running (that's how it has to be, sorry)
- `flac`, `metaflac` and `lame` must be installed and available in your bash $PATH
 - I recommend installing the above with Homebrew (`homebrew install flac` will provide everything you need)
- And your iPod or iPhone needs to be connected, natch

##Compiling
This program uses the Foundation and Scripting Bridge frameworks.

First, you need to generate the Scripting Bridge header file for iTunes.  In the same
folder as `main.m`, execute this:

`sdef /Applications/iTunes.app | sdp -fh --basename iTunes`

The `iTunes.h` header should be in your current folder.

Now compile with:

`gcc -framework Foundation -framework ScriptingBridge main.m`

This may change in the future.
