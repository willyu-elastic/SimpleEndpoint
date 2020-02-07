

#import <Foundation/Foundation.h>
#import "SystemRequestDelegate.h"

@implementation SystemExtensionLoadRequestDelegate

@synthesize successfulExtensionLoad;
@synthesize sema;

+ (NSBundle *)extensionBundle
{
    NSURL *extensionsDirURL = [NSURL fileURLWithPath:@"Contents/Library/SystemExtensions"
                                       relativeToURL:[[NSBundle mainBundle] bundleURL]];

    NSArray *extensionURLs = [[NSFileManager defaultManager]
          contentsOfDirectoryAtURL:extensionsDirURL
        includingPropertiesForKeys:nil
                           options:NSDirectoryEnumerationSkipsHiddenFiles
                             error:nil];

    NSURL *extensionURL       = [extensionURLs firstObject];
    NSBundle *extensionBundle = [NSBundle bundleWithURL:extensionURL];

    return extensionBundle;
}

- (OSSystemExtensionReplacementAction)request:(nonnull OSSystemExtensionRequest *)request
                  actionForReplacingExtension:(nonnull OSSystemExtensionProperties *)existing
                                withExtension:(nonnull OSSystemExtensionProperties *)ext
{
    NSLog(@"Replacing existing system extension");
    self.successfulExtensionLoad = true;
    
    if (dispatch_semaphore_signal(self.sema) == 0)
    {
        NSLog(@"Unable to wake up response thread for system extension loading");
    }
    
    return OSSystemExtensionReplacementActionReplace;
}

- (void)request:(nonnull OSSystemExtensionRequest *)request
    didFailWithError:(nonnull NSError *)error
{
    NSLog(@"Request to load system extension has failed! Errror: %s", [[error localizedDescription] UTF8String]);
    
    if (dispatch_semaphore_signal(self.sema) == 0)
    {
        NSLog(@"Unable to wake up response thread for system extension loading");
    }
}

- (void)request:(nonnull OSSystemExtensionRequest *)request
    didFinishWithResult:(OSSystemExtensionRequestResult)result
{
    NEFilterManager *sharedFilterManager = [NEFilterManager sharedManager];
    NSString *appName                    = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];

    [sharedFilterManager loadFromPreferencesWithCompletionHandler:^(NSError *_Nullable error) {
        
        NEFilterProviderConfiguration *configuration = [NEFilterProviderConfiguration new];
        configuration.filterSockets                  = true;
        sharedFilterManager.providerConfiguration    = configuration;
        
        if (appName != nil)
        {
            sharedFilterManager.localizedDescription = appName;
        }
        else
        {
            sharedFilterManager.localizedDescription = @"SimpleEndpointFilter";
        }
        
        sharedFilterManager.enabled = true;
        [sharedFilterManager saveToPreferencesWithCompletionHandler:^(NSError *_Nullable error) {
            
            if (nil != error)
            {
                NSLog(@"Unable to save system extension config: %s", [[error localizedDescription] UTF8String]);
            }

            self.successfulExtensionLoad = true;
            
            if (0 == dispatch_semaphore_signal(self.sema))
            {
                NSLog(@"Unable to wake up response thread for system extension loading");
            }
        }];
    }];
}

- (void)requestNeedsUserApproval:(nonnull OSSystemExtensionRequest *)request
{
    NSLog(@"Waiting on user approval...");
}

@end


@implementation SystemExtensionUnloadRequestDelegate

@synthesize successfulExtensionUnload;
@synthesize sema;

- (OSSystemExtensionReplacementAction)request:(nonnull OSSystemExtensionRequest *)request
                  actionForReplacingExtension:(nonnull OSSystemExtensionProperties *)existing
                                withExtension:(nonnull OSSystemExtensionProperties *)ext
{
    self.successfulExtensionUnload = false;
    if (0 == dispatch_semaphore_signal(self.sema))
    {
        NSLog(@"Unable to wake up response thread for system extension unloading");
    }

    return OSSystemExtensionReplacementActionCancel;
}

- (void)request:(nonnull OSSystemExtensionRequest *)request
    didFailWithError:(nonnull NSError *)error
{
    if (nil != error)
    {
        NSLog(@"Request to unload system extension has failed! Errror: %s", [[error localizedDescription] UTF8String]);
    }

    self.successfulExtensionUnload = false;
    if (0 == dispatch_semaphore_signal(self.sema))
    {
        NSLog(@"Unable to wake up response thread for system extension unloading");
    }
}

- (void)request:(nonnull OSSystemExtensionRequest *)request
    didFinishWithResult:(OSSystemExtensionRequestResult)result
{
    self.successfulExtensionUnload = true;

    if (OSSystemExtensionRequestWillCompleteAfterReboot == result)
    {
        NSLog(@"System extension will be fully unloaded after reboot");
    }

    if (0 == dispatch_semaphore_signal(self.sema))
    {
        NSLog(@"Unable to wake up response thread for system extension unloading");
    }
}

- (void)requestNeedsUserApproval:(nonnull OSSystemExtensionRequest *)request
{
    NSLog(@"Waiting on user approval...");
}

@end
