//
//  main.m
//  SimpleEndpointExtension
//
//  Created by will on 2/5/20.
//  Copyright © 2020 YourCompanyHere. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import "SharedIPC.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [NEProvider startSystemExtensionMode];
        [[IPCConnection shared] startListener];
    }
    
    dispatch_main();
}
