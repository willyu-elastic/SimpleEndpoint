//
//  FilterPacketProvider.m
//  SimpleEndpointExtension
//
//  Created by will on 2/5/20.
//  Copyright © 2020 YourCompanyHere. All rights reserved.
//

#import "FilterDataProvider.h"
#import "SharedIPC.h"

@implementation FilterDataProvider

- (void)startFilterWithCompletionHandler:(void (^)(NSError *error))completionHandler {
    completionHandler(nil);
}

- (void)stopFilterWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    completionHandler();
}

- (NEFilterNewFlowVerdict *)handleNewFlow:(NEFilterFlow *)flow {
    
    NSMutableDictionary<NSNumber*, NSObject*> *packetData = [NSMutableDictionary new];
    NEFilterSocketFlow *socketFlow = (NEFilterSocketFlow*)flow;
    
    if (socketFlow != nil)
    {
        NWHostEndpoint *remoteEndpoint = (NWHostEndpoint *)[socketFlow remoteEndpoint];
        NWHostEndpoint *localEndpoint = (NWHostEndpoint *)[socketFlow localEndpoint];
        
        if (remoteEndpoint != nil)
        {
            [packetData setObject:[NSNumber numberWithInt:[[remoteEndpoint port] intValue]] forKey:[NSNumber numberWithInt:RemotePort]];
            [packetData setObject:[remoteEndpoint hostname] forKey:[NSNumber numberWithInt: RemoteAddress]];
        }
        
        if (localEndpoint != nil)
        {
            [packetData setObject:[NSNumber numberWithInt:[[localEndpoint port] intValue]] forKey:[NSNumber numberWithInt:LocalPort]];
            [packetData setObject:[localEndpoint hostname] forKey:[NSNumber numberWithInt:LocalAddress]];
        }
        
        if ([packetData count] > 0)
        {
            [[IPCConnection shared] notifyListenerAboutNetworkEventWithDictionary:packetData withResponseHandler:^(bool success) {
                
                if (success == false)
                {
                    NSLog(@"Failed to notify about network event");
                }
            }];
        }
    }
    
    return [NEFilterNewFlowVerdict allowVerdict];
}

@end
