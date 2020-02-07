#pragma once

#import <Availability.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemExtensions/SystemExtensions.h>

@interface SystemExtensionLoadRequestDelegate : NSObject<OSSystemExtensionRequestDelegate>

///
/// @brief This static method will pull the bundle instance of our system extension
///        from a set relative path inside our .app
///
+ (NSBundle *)extensionBundle;

@property BOOL successfulExtensionLoad;
@property dispatch_semaphore_t sema;

@end


@interface SystemExtensionUnloadRequestDelegate : NSObject<OSSystemExtensionRequestDelegate>

@property BOOL successfulExtensionUnload;
@property dispatch_semaphore_t sema;

@end
