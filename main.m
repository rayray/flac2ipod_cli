//
//  main.m
//  flac2ipod_cli
//
//  Created by Raymond Edwards on 12-06-15
//

#import <Foundation/Foundation.h>
#include "stdlib.h"
#import "iTunes.h"

NSString* getFilepath(){
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    
    if([arguments count] < 2){
        printf("Usage: flac2ipod [flacFILE | flacDIR]\n");
        exit(0);
    }
    
    //NSProcessInfo expands the string for us, no need to massage it
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
    NSString *fps = runTask(@"/usr/bin/which", 
                            [NSArray arrayWithObjects:@"flac",@"metaflac",@"lame",nil], 
                            @"Finding tools...");
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
    NSString *m = runTask(mfpath, 
                          [NSArray arrayWithObjects:@"--export-tags-to=-", flacfile, nil], 
                          [NSString stringWithFormat:@"Obtaining metadata for %@",[flacfile lastPathComponent]]);
    //NSLog(@"%@",m);
    NSArray *tags = [m componentsSeparatedByString:@"\n"];
    //NSLog(@"%@",tags);
    NSMutableString *argstring = [NSMutableString stringWithString:@""];
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:@"-ta", @"ARTIST",
                       @"-tt",@"TITLE",
                       @"-tl",@"ALBUM",
                       @"-tn",@"TRACKNUMBER",
                       @"-tg",@"GENRE",
                       @"-ty",@"DATE", nil];
    
    for(NSString *t in tags){
        NSArray *f = [t componentsSeparatedByString:@"="];
        NSString *dasharg = [d objectForKey:[[f objectAtIndex:0] uppercaseString]];
        NSLog(@"dasharg: %@",dasharg);
        if(dasharg){
            [argstring appendString:dasharg];
            [argstring appendString:@" \'"];
            [argstring appendString:[f objectAtIndex:1]];
            [argstring appendString:@"\' "];
        }
    }

    return argstring;//args for lame
    
}

NSString* convertTrack(NSString *flacpath, NSString *lamepath, 
                       NSString *flacfile, NSString *lameargs){
    u_int32_t randomNum = arc4random_uniform(1000);//while im testing
    
    NSString *pathForMP3 = [flacfile stringByDeletingLastPathComponent];
    //NSLog(@"%@",[[flacfile lastPathComponent] stringByDeletingLastPathComponent]);
    NSString *filenameForMP3 = [[flacfile lastPathComponent] stringByDeletingPathExtension];
    //NSLog(@"%@",filenameForMP3);
    NSString *qmp3file = [NSString stringWithFormat:@"\'%@/%@-%d.mp3\'",pathForMP3,filenameForMP3,randomNum];
    NSString *mp3file = [NSString stringWithFormat:@"%@/%@-%d.mp3",pathForMP3,filenameForMP3,randomNum];
    NSLog(@"qmp3file: %@",qmp3file);
    NSString *qflacfile = [NSString stringWithFormat:@"\'%@\'",flacfile];
    NSLog(@"qflacfile: %@",qflacfile);
    
    NSTask *flac = [[NSTask alloc] init];
    NSTask *lame = [[NSTask alloc] init];
    
    NSPipe *pipeToLame = [NSPipe pipe];
    NSPipe *finalOutput = [NSPipe pipe];
    
    [flac setLaunchPath:flacpath];
    [flac setArguments:[NSArray arrayWithObjects:@"-sdc",qflacfile,nil]];
    [flac setStandardOutput:pipeToLame];
    [lame setLaunchPath:lamepath];
    [lame setArguments:[NSArray arrayWithObjects:@"-V0",lameargs,"-",qmp3file, nil]];
    [lame setStandardInput:pipeToLame];
    [lame setStandardOutput:finalOutput];
    printf("Converting %s\n",[flacfile UTF8String]);
    [flac launch];
    [lame launch];
    
    NSData *lameout = [[finalOutput fileHandleForReading] readDataToEndOfFile];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:mp3file]){
        printf("%s finished\n",[mp3file UTF8String]);
        return mp3file;
    }
    else{
        printf("Converting %s failed.\n",[flacfile UTF8String]);
        return nil;
    }
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
    
    /*if((dev = getDevice(iTunes)) == nil){
        printf("A usable device doesn't seem to be connected. Woops.\n");
        exit(1);
    }
    
    if((devpl = getDevicePlaylist(dev)) == nil){
        printf("Can't find the master playlist on the device. Woops.\n");
        exit(1);
    }
    */
    findPaths(&flacpath, &metaflacpath, &lamepath);
    NSString *lameargs = getTrackMetadata(metaflacpath, userfilepath);
    NSLog(@"lameargs in main: %@",lameargs);
    NSString *pathtomp3 = convertTrack(flacpath, lamepath, userfilepath, lameargs);
    NSLog(@"pathtomp3 in main: %@",pathtomp3);
    //NSLog(@"%@\n%@\n%@", flacpath, metaflacpath, lamepath);
    //convert();
    //pushToiPod(iTunes, devpl, userfilepath);
    
    //if(closeiTunesOnExit) [iTunes quit];
    
    [pool drain];
    return 0;
}