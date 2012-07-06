//
//  main.m
//  flac2ipod_cli
//
//  Created by Raymond Edwards on 12-06-15
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

NSString* getFilepath(){
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    
    if([arguments count] < 2){
        printf("Usage: flac2ipod [flacFILE | flacDIR]\n");
        exit(0);
    }
    
    return [arguments objectAtIndex:1];
}

iTunesSource* getDevice(iTunesApplication *iTunes){
    
    SBElementArray *srcs = [iTunes sources];
    iTunesSource *dev = nil;
    
    printf("Searching for device... ");
    for (iTunesSource *s in srcs){
        //we're going to assume there's only one device connected... sorry
        if([s kind] == iTunesESrcIPod) {
            dev = s;
            printf("found %s.\n", [[dev name] UTF8String]);
            return dev;
        }
    }
    return dev;
}

iTunesPlaylist* getDevicePlaylist(iTunesSource *dev){
    
    SBElementArray *pls = [dev playlists];
    iTunesPlaylist *devpl = nil;
    
    printf("Obtaining master playlist...\n");
    for(iTunesPlaylist *p in pls){
        //NSLog(@"name is: %@",[p name]);
        //NSLog(@"Is of type: %@", [p className]);
        if([[p name] isEqualToString:[dev name]]){
            devpl = p;
            return devpl;
        }
    }
    return devpl;
}

void printDevicePlaylist(iTunesPlaylist *p){
    
    SBElementArray *tracks = [p tracks];
    
    for(iTunesTrack *t in tracks){
        NSLog(@"name: %@",[t name]);
    }
}

NSString* runTask(NSString *path, NSArray *args, NSString *comment){
    NSTask *t = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    [t setLaunchPath:path];
    [t setArguments:args];
    [t setStandardOutput:output];
    printf("%s\n",[comment UTF8String]);
    [t launch];
    [t waitUntilExit];
    NSData *outdata = [[output fileHandleForReading] readDataToEndOfFile];
    [output release];
    return [[[NSString alloc] initWithData:outdata encoding:NSUTF8StringEncoding] autorelease];
}

void findPaths(NSString **flacpath, NSString **metaflacpath, NSString **lamepath){
    NSString *fps = runTask(@"/usr/bin/which", [NSArray arrayWithObjects:@"flac",@"metaflac",@"lame",nil], @"Finding tools...");
    NSArray *filepaths = [fps componentsSeparatedByString:@"\n"];
    
    if([filepaths count]!=4){
        printf("Didn't find all paths.\n");
        printf("Please ensure flac, metaflac, and lame are installed and are available in $PATH.\n");
        exit(1);
    }
    
    *flacpath = [filepaths objectAtIndex:0];
    printf("flac: %s\n", [*flacpath UTF8String]);
    *metaflacpath = [filepaths objectAtIndex:1];
    printf("metaflac: %s\n", [*metaflacpath UTF8String]);
    *lamepath = [filepaths objectAtIndex:2];
    printf("lame: %s\n", [*lamepath UTF8String]);
}

NSString* getTrackMetadata(NSString *mfpath, NSString *flacfile){
    NSString *m = runTask(mfpath, [NSArray arrayWithObjects:@"--export-tags-to=-", flacfile, nil], [NSString stringWithFormat:@"Obtaining metadata for %@",[flacfile lastPathComponent]]);

    return @"";
    
}

NSString* convertTrack(NSString *file){
    return @"";//path to mp3
}

void pushToiPod(iTunesApplication *iTunes, iTunesPlaylist *devpl, NSString *file){
    //let's try adding something
    iTunesTrack *track = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:file]]
                                  to:devpl];
    NSLog(@"track is: %@", track);
}

BOOL f2i(){
    return NO;
}

int main(int argc, const char * argv[]){
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    //BOOL closeiTunesOnExit = NO;
    
    if(![iTunes isRunning]){
        //closeiTunesOnExit = YES;
        //[iTunes run];
        printf("Please start iTunes and try again.\n");
        exit(1);
    }
    
    //NSFileManager *filemgr = [NSFileManager defaultManager];
    iTunesSource *dev = nil;
    iTunesPlaylist *devpl = nil;
    NSString *userfilepath = nil;
    NSString *flacpath = nil, *metaflacpath = nil, *lamepath = nil;
    
    userfilepath = getFilepath();
    
    if((dev = getDevice(iTunes)) == nil){
        printf("A usable device doesn't seem to be connected. Woops.\n");
        exit(1);
    }
    
    if((devpl = getDevicePlaylist(dev)) == nil){
        printf("Can't find the master playlist on the device. Woops.\n");
        exit(1);
    }
    
    findPaths(&flacpath, &metaflacpath, &lamepath);
    //NSLog(@"%@\n%@\n%@", flacpath, metaflacpath, lamepath);
    //convert();
    //pushToiPod(iTunes, devpl, userfilepath);
    
    //if(closeiTunesOnExit) [iTunes quit];
    
    [pool drain];
    return 0;
}