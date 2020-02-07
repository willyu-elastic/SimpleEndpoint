
#import <Foundation/Foundation.h>
#import "SharedIPC.h"

@interface
IPCConnection () // Begin class declaration

- (NSString *)extensionMachServiceNameFromBundle:(NSBundle *_Nonnull)bundle;
@end // End class declaration

@implementation IPCConnection // Begin class definition

// Create automatic getters/setters
@synthesize listener;
@synthesize currentConnection;
@synthesize delegate;

static IPCConnection *_sharedInstance;

+ (IPCConnection *)shared
{
    if (_sharedInstance == nil)
    {
        _sharedInstance = [IPCConnection new];
    }
    
    return _sharedInstance;
}

- (void)startListener
{
    NSString *machServiceName = [self extensionMachServiceNameFromBundle:[NSBundle mainBundle]];
    
    if (machServiceName != nil)
    {
        NSLog(@"Starting XPC listener for mach service: %@", machServiceName);
        NSXPCListener *newListener =
        [[NSXPCListener alloc] initWithMachServiceName:machServiceName];
        newListener.delegate = self;
        [newListener resume];
        self.listener = newListener;
    }
}

- (void)registerWithBundle:(NSBundle *)bundle
              withDelegate:(NSObject<DaemonCommunication> *)delegate
     withCompletionHandler:(void (^)(bool success))completionHandler
{
    self.delegate = delegate;
    
    if (currentConnection == nil)
    {
        NSXPCConnectionOptions options = {0};
        NSString *machServiceName      = [self extensionMachServiceNameFromBundle:bundle];
        NSXPCConnection *newConnection =
        [[NSXPCConnection alloc] initWithMachServiceName:machServiceName options:options];
        
        // The exported object is the delegate
        newConnection.exportedInterface =
        [NSXPCInterface interfaceWithProtocol:@protocol(DaemonCommunication)];
        newConnection.exportedObject = delegate;
        
        // the remote object is the provider's IPCConnection instance
        newConnection.remoteObjectInterface =
        [NSXPCInterface interfaceWithProtocol:@protocol(ProviderCommunication)];
        
        currentConnection = newConnection;
        [newConnection resume];
        
        NSObject<ProviderCommunication> *providerProxy =
        [newConnection remoteObjectProxyWithErrorHandler:^(NSError *_Nonnull error) {
            NSLog(@"Failed to register with the provider: %@", [error localizedDescription]);
            
            if (self.currentConnection != nil)
            {
                [self.currentConnection invalidate];
                self.currentConnection = nil;
            }
            
            completionHandler(false);
        }];
        
        if (providerProxy != nil)
        {
            [providerProxy registerWithCompletionHandler:completionHandler];
        }
    }
    else
    {
        NSLog(@"Already registered with the provider");
        completionHandler(true);
    }
}

- (void)notifyListenerAboutNetworkEventWithDictionary:(NSDictionary *)data
                                  withResponseHandler:
(void (^_Nonnull)(bool success))responseHandler
{
    if (self.currentConnection != nil)
    {
        NSObject<DaemonCommunication> *appProxy =
        [self.currentConnection remoteObjectProxyWithErrorHandler:^(NSError *_Nonnull error) {
            NSLog(@"Failed to XPC to app with data: %@", [error localizedDescription]);
            self.currentConnection = nil;
            responseHandler(true);
        }];
        
        if (appProxy != nil)
        {
            [appProxy notifyNetworkEventWithDictionary:data withCompletionHandler:responseHandler];
        }
    }
    else
    {
        NSLog(@"No app registered");
    }
}

- (NSString *)extensionMachServiceNameFromBundle:(NSBundle *_Nonnull)bundle
{
    NSDictionary *NEKeys = [bundle objectForInfoDictionaryKey:@"NetworkExtension"];
    if (NEKeys != nil)
    {
        NSString *machServiceName = NEKeys[@"NEMachServiceName"];
        return machServiceName;
    }
    
    return nil;
}

- (BOOL)listener:(NSXPCListener *)listener
shouldAcceptNewConnection:(nonnull NSXPCConnection *)newConnection
{
    // The exported object is this IPCConnection instance
    newConnection.exportedInterface =
    [NSXPCInterface interfaceWithProtocol:@protocol(ProviderCommunication)];
    newConnection.exportedObject = self;
    
    // The remote object is the delegate of the app's IPCConnection instnace
    newConnection.remoteObjectInterface =
    [NSXPCInterface interfaceWithProtocol:@protocol(DaemonCommunication)];
    
    newConnection.invalidationHandler = ^{
        self.currentConnection = nil;
    };
    
    newConnection.interruptionHandler = ^{
        self.currentConnection = nil;
    };
    
    self.currentConnection = newConnection;
    [newConnection resume];
    
    return TRUE;
}

- (void)registerWithCompletionHandler:(void (^)(bool success))completionHandler
{
    NSLog(@"App registered");
    completionHandler(true);
}

@end
