//
//  main.m
//  flac2ipod_cli
//
//  Created by Raymond Edwards on 12-06-15
//

#import <Foundation/Foundation.h>
#import "stdlib.h"
#import "iTunes.h"

//global flags
BOOL dealWithiTunes = NO;
BOOL inXcode = NO;
BOOL ignoreiPod = YES;
//============

NSMutableArray *getFLACsFromDirectory(NSString *path){
    
    if(![path hasSuffix:@"/"]) path = [NSString stringWithFormat:@"%@/",path];
    
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *filelist = [fm contentsOfDirectoryAtPath:path error:nil];
    
    //NSLog(@"filelist = %@",filelist);
    
    printf("Searching %s for FLACs\n", [path UTF8String]);
    for(NSString *s in filelist){
        if(![[s pathExtension] caseInsensitiveCompare:@"flac"]){
            NSString *pathtoflacfile = [NSString stringWithFormat:@"%@%@",path,s];
            [files addObject:pathtoflacfile];
        }
    }
    
    printf("Found %d files.\n",[files count]);
    
    return files;
}

NSArray* parseArgsAndGetFileList(){
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    
    if([arguments count] < 2){
        printf("Usage: flac2ipod [flacFILE | flacDIR]\n\tTry --help for more info.\n");
        exit(0);
    }
    
    if([[arguments objectAtIndex:1] isEqualToString:@"--help"]){
        printf("Usage: flac2ipod [options] [flacFILE | flacDIR]\n");
        printf("Options:\n");
        printf("\t-t\tMake the app open and close iTunes\n");
        printf("\t-x\tXcode mode; the app will make some\n\t\tassumptions about paths to binaries\n");
        exit(1);
    }
    
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString *dirpath = [[NSString alloc] init];
    BOOL isDir;
    BOOL singleFiles = NO;
    
    for(int i=1; i < [arguments count]; i++){
        NSString *s = [arguments objectAtIndex:i];
        
        if([s hasPrefix:@"-"] && [s length]==2){
            if([s isEqualToString:@"-x"]){
                inXcode = YES;
                NSLog(@"Xcode mode.");
            }
            else if([s isEqualToString:@"-t"]) dealWithiTunes = YES;
            else {
                printf("%s not recognized. Try --help.\n",[s UTF8String]);
                exit(1);
            }
        }
        else{
            s = [s stringByExpandingTildeInPath];
            if([[NSFileManager defaultManager] fileExistsAtPath:s isDirectory:&isDir]){
                if(isDir){
                    if(!singleFiles){
                        dirpath = s;
                        files = getFLACsFromDirectory(dirpath);
                        break;
                    }
                    else{
                        printf("Only a sequence of files or one directory is allowed.\n");
                        exit(1);
                    }
                }
                else{
                    singleFiles = YES;//prevent user from adding a directory now
                    [files addObject:s];
                }
            }
            
            else printf("%s doesn't appear to exist.\n", [s UTF8String]);
        }
    }
    
    NSLog(@"%@",files);
    
    return files;
    //return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:[path UTF8String] 
    //                                                                   length:[path length]];
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
    
    if(inXcode){
        *flacpath = @"/usr/local/bin/flac";
        *metaflacpath = @"/usr/local/bin/metaflac";
        *lamepath = @"/usr/local/bin/lame";
    }
    else{
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
}

NSMutableArray* getTrackMetadata(NSString *mfpath, NSString *flacfile){
    NSString *m = runTask(mfpath, 
                          [NSArray arrayWithObjects:@"--export-tags-to=-", flacfile, nil], 
                          [NSString stringWithFormat:@"Obtaining metadata for %@",[flacfile lastPathComponent]]);
    //NSLog(@"%@",m);
    NSArray *tags = [m componentsSeparatedByString:@"\n"];
    //NSLog(@"%@",tags);
    NSMutableString *argstring = [NSMutableString stringWithString:@""];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:@"--ta", @"ARTIST",
                       @"--tt",@"TITLE",
                       @"--tl",@"ALBUM",
                       @"--tn",@"TRACKNUMBER",
                       @"--tg",@"GENRE",
                       @"--ty",@"DATE", nil];
    
    for(NSString *t in tags){
        NSArray *f = [t componentsSeparatedByString:@"="];
        NSString *dasharg = [d objectForKey:[[f objectAtIndex:0] uppercaseString]];
        //NSLog(@"dasharg: %@",dasharg);
        if(dasharg){
            [args addObject:dasharg];
            [args addObject:[f objectAtIndex:1]];
            [argstring appendFormat:@"%@ \'%@\' ",
             dasharg,[[f objectAtIndex:1] stringByReplacingOccurrencesOfString:@"'" 
                                                                    withString:@"\\'"]];
        }
    }
    //NSLog(@"%@",args);
    return args;//args for lame
    
}

NSString* convertTrack(NSString *flacpath, NSString *lamepath, 
                       NSString *flacfile, NSMutableArray *metadata){
    u_int32_t randomNum = arc4random_uniform(1000);//while im testing
    NSString *pathForMP3 = [flacfile stringByDeletingLastPathComponent];
    NSString *filenameForMP3 = [[flacfile lastPathComponent] stringByDeletingPathExtension];
    NSString *mp3file = [NSString stringWithFormat:@"%@/%@-%d.mp3",pathForMP3,filenameForMP3,randomNum];
        
    NSMutableArray *lameargs = [NSMutableArray arrayWithObjects:@"-V0",@"-",mp3file,nil];
    
    int index = 1;
    
    for(NSString *s in metadata){
        [lameargs insertObject:s atIndex:index];
        index++;
    }
    
    NSTask *flac = [[NSTask alloc] init];
    NSTask *lame = [[NSTask alloc] init];
    
    NSPipe *pipeToLame = [NSPipe pipe];
    NSPipe *finalOutput = [NSPipe pipe];
    
    [flac setLaunchPath:flacpath];
    [flac setArguments:[NSArray arrayWithObjects:@"-sdc",flacfile,nil]];
    [flac setStandardOutput:pipeToLame];
    [lame setLaunchPath:lamepath];
    [lame setArguments:[NSArray arrayWithArray:lameargs]];
    [lame setStandardInput:pipeToLame];
    [lame setStandardOutput:finalOutput];
    [lame setStandardError:finalOutput];//because LAME seems to print to stderr even when nothing is wrong
    printf("Converting %s\n",[flacfile UTF8String]);
    [flac launch];
    [lame launch];
    
    NSData *lameout = [[finalOutput fileHandleForReading] readDataToEndOfFile];
    //NSString *lameooutstring = [[[NSString alloc] initWithData:lameout encoding:NSUTF8StringEncoding] autorelease];

    [pipeToLame release];
    [finalOutput release];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:mp3file]){
        printf(" - %s finished\n",[mp3file UTF8String]);
        return mp3file;
    }
    else{
        printf("Converting %s failed.\n",[flacfile UTF8String]);
        return nil;
    } 
    
    //return @"";
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
    
    if(![iTunes isRunning]){
        if(dealWithiTunes) [iTunes run];
        else{
            printf("Please start iTunes and try again, or use \"-t\".\n");
            exit(1);
        }
    }
    
    iTunesSource *dev = nil;
    iTunesPlaylist *devpl = nil;
    NSArray *filelist = nil;
    NSString *flacpath = nil, *metaflacpath = nil, *lamepath = nil;
    
    filelist = parseArgsAndGetFileList();
    
    if(ignoreiPod) printf("Testing mode. Ignoring iPod.\n");
    
    if(!ignoreiPod&&(dev = getDevice(iTunes))){
        printf("A usable device doesn't seem to be connected. Woops.\n");
        exit(1);
    }
    
    if(!ignoreiPod&&(devpl = getDevicePlaylist(dev))){
        printf("Can't find the master playlist on the device. Woops.\n");
        exit(1);
    }
    
    findPaths(&flacpath, &metaflacpath, &lamepath);
    //NSMutableArray *lameargs = getTrackMetadata(metaflacpath, userfilepath);
    //NSString *pathtomp3 = convertTrack(flacpath, lamepath, userfilepath, lameargs);
    //convert();
    //pushToiPod(iTunes, devpl, userfilepath);
    
    if(dealWithiTunes) [iTunes quit];
    
    [pool drain];
    return 0;
}