#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger,
    NetworkEventDataTypes) {
    NetworkEventDataTypesNone = 0,
    RemoteAddress             = 1,
    LocalAddress              = 2,
    LocalPort                 = 3,
    RemotePort                = 4,
    NetworkEventType          = 5,
    NetworkDirection          = 6,
    NetworkProtocol           = 7,
};

///
/// @brief This protocol is implemented by the receiving process to be called
///        by the System Extension to notify the receving process of a new
///        network event that has occured
///
@protocol DaemonCommunication<NSObject>


- (void)notifyNetworkEventWithDictionary:(NSDictionary<NSNumber *,
                                             NSObject *> *_Nonnull)data
                   withCompletionHandler:(void (^_Nonnull)(bool success))reply;
@end

///
/// @brief This protocol is implemented by the receiving process to be called
///        by the System Extension to notify the receving process of a new
///        network event that has occured
///
@protocol ProviderCommunication<NSObject>
- (void)registerWithCompletionHandler:(void (^_Nonnull)(bool success))completionHandler;
@end

///
/// @brief This is an Objective C class that is used by both the receiving application
///        and the System Extension to communicate with each other
///
@interface IPCConnection : NSObject<NSXPCListenerDelegate, ProviderCommunication>

// Used only by the System Extension side of IPC. Need to
// keep a reference to listener to prevent ARC from cleaning it up after
// we initialize a new listener
@property(nonatomic, retain) NSXPCListener *_Nonnull listener;

// The underlying connection between the System Extension and the receiving process
@property(nonatomic, retain) NSXPCConnection *_Nullable currentConnection;

// This is set to the delegate that is passed in during IPC registration
@property(nonatomic, weak) NSObject<DaemonCommunication> *_Nullable delegate;

///
/// @brief This method will return a shared static instance for IPCing back and forth between
///        the System Extension and the receiving application
///
/// @returns A static shared instance (singleton) to IPCConnection object
///
+ (IPCConnection *_Nonnull)shared;

///
/// @brief This method is called by the receiving application to intiate a connection with
///        the System Extension
///
/// @param[in] bundle This is the bundle to connect with, in this case the bundle is the System
/// Extension
///
/// @param[in] delegate This parameter is an instance of an object that implements the
/// AppCommunication
///                     protocol and is the exported interface used to communicate with the
///                     receiving application
///
/// @param[in] completionHandler This is a callback passed in that is called by this method once
/// registration has
///                              finished successfully or has failed
///
- (void)registerWithBundle:(NSBundle *_Nonnull)bundle
              withDelegate:(NSObject<DaemonCommunication> *_Nonnull)delegate
     withCompletionHandler:(void (^_Nonnull)(bool success))completionHandler;

///
/// @brief This method is called by the System Extension to send over information regarding an new
/// network event
///
/// @param[in] data This is an NSDictionary that contains information about the network event
///                 such as IP address, port, and any possible DNS queries
///
/// @param[in] responseHandler This is a callback that is passed to the receiving application to
/// call once it has successfully
///                            received the data
///
- (void)notifyListenerAboutNetworkEventWithDictionary:(NSDictionary<NSNumber *,
                                                          NSObject *> *_Nonnull)data
                                  withResponseHandler:
                                      (void (^_Nonnull)(bool success))responseHandler;

///
/// @brief This method is part of the protocol defined by NSXPCListenerDelegate which this
///        class implements. It is called by the XPC subsystem to determine if the new connection
///        should be accepted or not
///
/// @param[in] newConnection The new connection to save and interact with if it is accepted
///
- (BOOL)listener:(NSXPCListener *_Nonnull)listener
    shouldAcceptNewConnection:(NSXPCConnection *_Nonnull)newConnection;

///
/// @brief This method is called by the System Extension to begin listening for new connections
///        from the receiving application
///
- (void)startListener;

///
/// @brief This method is part of the protocol ProviderCommunication and called by the receiving
///        application to register with the System Extension
///
/// @param[in] completionHandler A callback that is called by the System Extension to notify the
///                              receiving application that registration was successful
///
- (void)registerWithCompletionHandler:(void (^_Nonnull)(bool success))completionHandler;

@end
