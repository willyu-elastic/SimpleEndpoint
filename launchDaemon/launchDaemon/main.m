
#import <Foundation/Foundation.h>
#import "ESHooks.h"
#import "SharedIPC.h"

#define SYSEXT_DIR @"/Applications/SimpleEndpointApp.app/Contents/Library/SystemExtensions"

@interface IPCConnectionDelegate : NSObject<DaemonCommunication>
@end

@implementation IPCConnectionDelegate

- (void)notifyNetworkEventWithDictionary:(NSDictionary<NSNumber *,NSObject *> * _Nonnull)data withCompletionHandler:(void (^ _Nonnull)(bool))reply {
    
    if ([data count] > 0)
    {
        NSLog(@"New socket flow detected");
        
        NSNumber *remotePort = (NSNumber *)[data objectForKey:[NSNumber numberWithInt:RemotePort]];
        NSNumber *localPort = (NSNumber *)[data objectForKey:[NSNumber numberWithInt:LocalPort]];
        
        NSString *localAddress = (NSString *)[data objectForKey:[NSNumber numberWithInt:LocalAddress]];
        NSString *remoteAddress = (NSString *)[data objectForKey:[NSNumber numberWithInt:RemoteAddress]];
        
        if (remoteAddress != nil)
        {
            NSLog(@"Remote address: %@", remoteAddress);
        }
        
        if (remotePort != nil)
        {
            NSLog(@"Remote port: %d", [remotePort intValue]);
        }
        
        if (localAddress != nil)
        {
            NSLog(@"Local address: %@", localAddress);
        }
        
        if (localPort != nil)
        {
            NSLog(@"Local port: %d", [localPort intValue]);
        }
        
        reply(true);
    }
    else
    {
        // Received no data
        reply(false);
    }
}

@end

int main(int argc, const char * argv[]) {
    
    @autoreleasepool {
        
        NSURL *extensionsDirURL = [NSURL fileURLWithPath: SYSEXT_DIR];
        NSArray *extensionURLs  = [[NSFileManager defaultManager]
                                   contentsOfDirectoryAtURL:extensionsDirURL
                                   includingPropertiesForKeys:nil
                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                   error:nil];
        
        NSURL *extensionURL       = [extensionURLs firstObject];
        NSBundle *extensionBundle = [NSBundle bundleWithURL:extensionURL];
        
        IPCConnectionDelegate *ipcDelegate = [IPCConnectionDelegate new];
        
        InstallHooks();
        
        [[IPCConnection shared] registerWithBundle:extensionBundle withDelegate:ipcDelegate withCompletionHandler:^(bool success) {
            
            if (success)
            {
                NSLog(@"Successfully registered with system extension");
            }
            else
            {
                NSLog(@"Registration with system extension failed");
            }
        }];
        
        dispatch_main();
    }
}
