//
//  main.m
//  flac2ipod_cli
//
//  Created by Raymond Edwards on 12-06-15
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        
        iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        
        if([iTunes isRunning]){
            NSFileManager *filemgr;
            NSString *currentpath;
            SBElementArray *srcs = [iTunes sources], *pls; //*devplTracks;
            iTunesSource *dev = nil;
            iTunesPlaylist *devpl = nil;
            NSString *filepath = [[NSString stringWithUTF8String:argv[1]] stringByExpandingTildeInPath];
            //NSLog(@"%@",filepath);
            filemgr = [NSFileManager defaultManager];
            currentpath = [filemgr currentDirectoryPath];
            NSLog (@"Current directory is %@", currentpath);
            //if ([filemgr changeCurrentDirectoryPath: @"/Users/dnomy/"] == NO)
            //    NSLog (@"Cannot change directory.");
            //NSURL* file = [NSURL fileURLWithPath:@"~/Desktop/temp/" isDirectory:NO];
            //NSString *track = @"";
            
            
            for (iTunesSource *obj in srcs){
                //we're going to assume there's only one device connected... sorry
                if([obj kind] == iTunesESrcIPod) {
                    dev = obj;
                    break;
                }
            }
            
            if(dev == nil){
                printf("A usable device doesn't seem to be connected. Woops.\n");
                exit(1);
            }
            
            //NSLog(@"%lld",[dev freeSpace]);
            pls = [dev playlists];
            for(iTunesPlaylist *p in pls){
                //NSLog(@"name is: %@",[p name]);
                //NSLog(@"Is of type: %@", [p className]);
                if([[p name] isEqualToString:@"iPod touch"]){
                    devpl = p;
                    break;
                }
            }
            
            if(devpl == nil){
                printf("Can't find the master playlist on the device. Woops.\n");
                exit(1);
            }
            
            //devplTracks = [devpl tracks];
            //for(iTunesTrack *t in devplTracks){
            //    NSLog(@"name: %@",[t name]);
            //}
            
            //let's try adding something
            iTunesTrack *track = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:filepath]]
                     to:devpl];
            NSLog(@"track is: %@", track);
        }
        else printf("Please start iTunes and try again.\n");
    }
    return 0;
}