
#import <Cocoa/Cocoa.h>

#include <errno.h>
#include <string>

#import "SystemRequestDelegate.h"

static constexpr int32_t MIN_ARGS = 2;
static constexpr std::string_view INSTALL_ARG = "--install";
static constexpr std::string_view UNINSTALL_ARG = "--uninstall";

static bool InstallSystemExtension()
{
    NSBundle *extensionBundle                                          = [SystemExtensionLoadRequestDelegate extensionBundle];
    
    OSSystemExtensionRequest *request                                  = [OSSystemExtensionRequest
                                                                          activationRequestForExtension:[extensionBundle bundleIdentifier]
                                                                          queue:dispatch_get_main_queue()];
    
    SystemExtensionLoadRequestDelegate *systemExtensionRequestDelegate = [SystemExtensionLoadRequestDelegate new];
    OSSystemExtensionManager *manager                                  = [OSSystemExtensionManager sharedManager];
    
    systemExtensionRequestDelegate.successfulExtensionLoad = false;
    systemExtensionRequestDelegate.sema                    = dispatch_semaphore_create(0);
    
    // Have the request call our newly allocated delegate when the request state changes
    request.delegate = systemExtensionRequestDelegate;
    
    
    [manager submitRequest:request];
    
    // Wait for the async path of extension approval to finish
    dispatch_semaphore_wait(systemExtensionRequestDelegate.sema, DISPATCH_TIME_FOREVER);
    
    return systemExtensionRequestDelegate.successfulExtensionLoad;
}

static bool UninstallSystemExtension()
{
    NSBundle *extensionBundle                                          = [SystemExtensionLoadRequestDelegate extensionBundle];
    
    OSSystemExtensionRequest *request                                  = [OSSystemExtensionRequest
                                                                          deactivationRequestForExtension:[extensionBundle bundleIdentifier]
                                                                          queue:dispatch_get_main_queue()];
    
    SystemExtensionUnloadRequestDelegate *systemExtensionRequestDelegate = [SystemExtensionUnloadRequestDelegate new];
    OSSystemExtensionManager *manager                                  = [OSSystemExtensionManager sharedManager];
    
    systemExtensionRequestDelegate.successfulExtensionUnload = false;
    systemExtensionRequestDelegate.sema                    = dispatch_semaphore_create(0);
    
    // Have the request call our newly allocated delegate when the request state changes
    request.delegate = systemExtensionRequestDelegate;
    
    
    [manager submitRequest:request];
    
    // Wait for the async path of extension approval to finish
    dispatch_semaphore_wait(systemExtensionRequestDelegate.sema, DISPATCH_TIME_FOREVER);
    
    return systemExtensionRequestDelegate.successfulExtensionUnload;
}

int main(int argc, const char * argv[]) {
    
    if (argc == MIN_ARGS)
    {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            
            int result = EINVAL;
            
            @autoreleasepool {
                
                if (INSTALL_ARG.compare(argv[1]) == 0)
                {
                    result = InstallSystemExtension() == true ? 0 : -1;
                    exit(result);
                }
                else if (UNINSTALL_ARG.compare(argv[1]) == 0)
                {
                        result = UninstallSystemExtension() == true ? 0 : -1;
                        exit(result);
                }
                else
                {
                    exit(result);
                }
            }
        });
        
        dispatch_main();
    }
    
    return EINVAL;
}
