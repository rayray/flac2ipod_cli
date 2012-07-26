# FLAC2iPod CLI for OS X

##Current status 
Usable, but I've only tested with my iPod on the computer it is registered with, 
so I make no guarantees about how it will operate in other situations.  It won't
brick your device, but who knows how iTunes will react in some circumstances.

**Back up your playlists/music, and of course, use at your own risk.**

Multithreading work is in progress.

##Description
This is a command line program that accepts either FLAC file(s) or a 
directory of FLACs, converts the FLACs to MP3s, and loads
the MP3s to a connected iPod or iPhone.

`flac2ipod` will only take the FLACs in the top level of your directory, ignoring
any subdirectories.  This seems safe.

The loaded MP3s bypass the iTunes Library, and after syncing, the MP3s
will be deleted from your computer.

The following metadata is carried over to MP3:

- Artist
- Album
- Track title
- Date
- Track number
- Genre

##Example Usage
Plug in your iDevice and open iTunes.

Put "a flac flacy.flac" on your device.

    ./flac2ipod /Volumes/My\ External\ Musics/a\ flac\ flacy.flac

Put "song1.flac" and "song2.flac" on your device.

    ./flac2ipod song1.flac song2.flac

Put a directory of FLACs on your device.

    ./flac2ipod /Volumes/My\ External\ Musics/Songs\ To\ Fan\ The\ Flames\ of\ Discontent/

##Running Requirements
- OS X Leopard or later
- iTunes must be running (that's how it has to be, sorry)
- `flac`, `metaflac` and `lame` must be installed and available in your bash $PATH
 - I recommend installing the above with [Homebrew](http://mxcl.github.com/homebrew/) (`brew install flac` will provide everything you need)
- And your iPod or iPhone needs to be connected, natch

##TO-DO
- Add album art if available
- Multithreaded conversion of multiple files
- Find bugs
- autotools

##Compiling
This program uses the Foundation and Scripting Bridge frameworks.

First, you need to generate the Scripting Bridge header file for iTunes.  In the same
folder as `main.m`, execute this:

    sdef /Applications/iTunes.app | sdp -fh --basename iTunes

The `iTunes.h` header should be in your current folder.

Now compile with:

    gcc -std=c99 -framework Foundation -framework ScriptingBridge main.m -o flac2ipod

This may change in the future.
