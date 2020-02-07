
#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>
#import <bsm/libbsm.h>
#import <mach/mach_time.h>

#include <map>
#include <iostream>

#include "ESHooks.h"

#define TIME_BUF_MAX 30 // Technically only need 26, but 30 is a round number

static void HandleExecAuth(const es_message_t* p_msg);
static void HandleKextloadAuth(const es_message_t* p_msg);
static void HandleMountAuth(const es_message_t* p_msg);
static void HandleRenameAuth(const es_message_t* p_msg);
static void HandleUnlinkAuth(const es_message_t* p_msg);

static void HandleForkNotification(const es_message_t* p_msg);

static void HandleCreateNotification(const es_message_t* p_msg);
static void HandleExchangeDataNotification(const es_message_t* p_msg);
static void HandleExitNotification(const es_message_t* p_msg);
static void HandleKextUnloadNotification(const es_message_t* p_msg);
static void HandleLinkNotification(const es_message_t* p_msg);
static void HandleIOKitOpenNotification(const es_message_t* p_msg);

typedef void(*event_handler_t)(const es_message_t*);

es_client_t* g_client = nullptr;

// Passed into es_subscribe to tell the EndpointSecurity framework what we intend to
// subscribe to. Not const because the function signature for es_subscribe dictates it.
es_event_type_t g_subscribed_events[] =
{
    ES_EVENT_TYPE_AUTH_EXEC,
    ES_EVENT_TYPE_AUTH_KEXTLOAD,
    ES_EVENT_TYPE_AUTH_MOUNT,
    ES_EVENT_TYPE_AUTH_RENAME,
    ES_EVENT_TYPE_AUTH_UNLINK,
    ES_EVENT_TYPE_NOTIFY_FORK,
    ES_EVENT_TYPE_NOTIFY_CREATE,
    ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA,
    ES_EVENT_TYPE_NOTIFY_EXIT,
    ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD,
    ES_EVENT_TYPE_NOTIFY_LINK,
    ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN
};

std::map<es_event_type_t, event_handler_t> event_handler_map =
{
    {ES_EVENT_TYPE_AUTH_EXEC,     HandleExecAuth},
    {ES_EVENT_TYPE_AUTH_KEXTLOAD, HandleKextloadAuth},
    {ES_EVENT_TYPE_AUTH_MOUNT,    HandleMountAuth},
    {ES_EVENT_TYPE_AUTH_RENAME,   HandleRenameAuth},
    {ES_EVENT_TYPE_AUTH_UNLINK,   HandleUnlinkAuth},
    
    {ES_EVENT_TYPE_NOTIFY_FORK,         HandleForkNotification},
    {ES_EVENT_TYPE_NOTIFY_CREATE,       HandleCreateNotification},
    {ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA, HandleExchangeDataNotification},
    {ES_EVENT_TYPE_NOTIFY_EXIT,         HandleExitNotification},
    {ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD,   HandleKextUnloadNotification},
    {ES_EVENT_TYPE_NOTIFY_LINK,         HandleLinkNotification},
    {ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN,   HandleIOKitOpenNotification},
};

static void HandleForkNotification(const es_message_t* p_msg)
{
    const es_event_fork_t* p_fork_notification = &p_msg->event.fork;
    pid_t new_pid = audit_token_to_pid(p_fork_notification->child->audit_token);
    
    NSLog(@"ppid %d forked pid %d", p_fork_notification->child->ppid, new_pid);
}

static void HandleCreateNotification(const es_message_t* p_msg)
{
    const es_event_create_t* p_create_notification = &p_msg->event.create;
    pid_t pid = audit_token_to_pid(p_msg->process->audit_token);

    if (p_create_notification->destination.new_path.filename.data != nullptr)
    {
        NSLog(@"pid %d creating file %s", pid, p_create_notification->destination.new_path.filename.data);
    }
}

static void HandleExchangeDataNotification(const es_message_t* p_msg)
{
    const es_event_exchangedata_t* p_exchangedata_notification = &p_msg->event.exchangedata;
    pid_t pid = audit_token_to_pid(p_msg->process->audit_token);
    
    if (p_exchangedata_notification->file1)
    {
        NSLog(@"pid %d exchanging data between file %s and file %s",
              pid, p_exchangedata_notification->file1->path.data, p_exchangedata_notification->file2->path.data);
    }
}

static void HandleExitNotification(const es_message_t* p_msg)
{
    pid_t pid = audit_token_to_pid(p_msg->process->audit_token);
    NSLog(@"pid %d has exited", pid);
}

static void HandleKextUnloadNotification(const es_message_t* p_msg)
{
    const es_event_kextunload_t* p_kextunload_notification = &p_msg->event.kextunload;
    NSLog(@"Kext ID: %s unloaded", p_kextunload_notification->identifier.data);
}

static void HandleLinkNotification(const es_message_t* p_msg)
{
    const es_event_link_t* p_link_notification = &p_msg->event.link;
    pid_t pid = audit_token_to_pid(p_msg->process->audit_token);
    
    if (p_link_notification->source)
    {
        NSLog(@"pid %d creating link from %s to path %s",
              pid, p_link_notification->source->path.data, p_link_notification->target_filename.data);
    }
}

static void HandleIOKitOpenNotification(const es_message_t* p_msg)
{
    const es_event_iokit_open_t* p_iokit_open_notification = &p_msg->event.iokit_open;
    pid_t pid = audit_token_to_pid(p_msg->process->audit_token);
    NSLog(@"pid %d opened iokit device %s", pid, p_iokit_open_notification->user_client_class.data);
}

static void HandleExecAuth(const es_message_t* p_msg)
{
    uint64_t responseMachTime = mach_absolute_time();
    uint64_t responseMachDeadlineDelta = p_msg->deadline - responseMachTime;
 
    // Make sure we have time to do analysis and respond
    if (responseMachDeadlineDelta >= (10 * NSEC_PER_SEC))
    {
        __block es_message_t* pCopiedMessage = es_copy_message(p_msg);

        // Perform analysis work and deadline management
        // on a seperate thread
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      
            __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            const es_event_exec_t* p_exec_notification = &pCopiedMessage->event.exec;
            
            pid_t pid = audit_token_to_pid(p_exec_notification->target->audit_token);
        
            if (p_exec_notification->target)
            {
                if (p_exec_notification->target->executable)
                {
                    NSLog(@"Process id %d is being started by parent process id %d with binary image %s", pid,
                          p_exec_notification->target->ppid, p_exec_notification->target->executable->path.data);
                }
            }
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            
                // Perform analysis that may have blocking operations.
                sleep(1);
            
                // Analysis complete, wake up the waiting thread
                (void)dispatch_semaphore_signal(sema);
            });

            // Wait for the analysis thread to signal us,
            // otherwise wait until 1 second before the deadline
            long result = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, responseMachDeadlineDelta - (1 * NSEC_PER_SEC)));
        
            if (result != 0 )
            {
                std::cout << "timed out performing analysis" << std::endl;
            }

            // This can be ES_AUTH_RESULT_DENY as well depending on
            // what your analysis has returned
            es_respond_auth_result(g_client, pCopiedMessage, ES_AUTH_RESULT_ALLOW, false);
            
            es_free_message(pCopiedMessage);
            pCopiedMessage = nullptr;

        });
           
    }
    else
    {
        NSLog(@"Skipping analysis because we don't have enough time to perform it");
    }

    // Return without responding to the original message,
    // it will be responded to in another thread
}

static void HandleKextloadAuth(const es_message_t* p_msg)
{
    const es_event_kextload_t* p_kextload_notification = &p_msg->event.kextload;
    
    NSLog(@"Kext ID: %s", p_kextload_notification->identifier.data);
    
    es_respond_auth_result(g_client, p_msg, ES_AUTH_RESULT_ALLOW, false);
}

static void HandleMountAuth(const es_message_t* p_msg)
{
    const es_event_mount_t* p_mount_notification = &p_msg->event.mount;
    
    NSLog(@"Mounting fileystem %s at mount point %s",
          p_mount_notification->statfs->f_fstypename, p_mount_notification->statfs->f_mntonname);
        
    es_respond_auth_result(g_client, p_msg, ES_AUTH_RESULT_ALLOW, false);
}

static void HandleRenameAuth(const es_message_t* p_msg)
{
    const es_event_rename_t* p_rename_notification = &p_msg->event.rename;
    
    if (p_rename_notification->source)
    {
        if (p_rename_notification->destination_type == ES_DESTINATION_TYPE_EXISTING_FILE)
        {
            if (p_rename_notification->destination.existing_file)
            {
                NSLog(@"Renaming source file %s to existing file %s", p_rename_notification->source->path.data, p_rename_notification->destination.existing_file->path.data);
            }
        }
        else
        {
            NSLog(@"Renaming source file %s to new file %s", p_rename_notification->source->path.data,
                  p_rename_notification->destination.new_path.filename.data);
        }
    }
    es_respond_auth_result(g_client, p_msg, ES_AUTH_RESULT_ALLOW, false);
}

static void HandleUnlinkAuth(const es_message_t* p_msg)
{
    const es_event_unlink_t* p_unlink_notification = &p_msg->event.unlink;
    
    if (p_unlink_notification->target)
    {
        NSLog(@"file %s being unlinked", p_unlink_notification->target->path.data);
    }
    
    es_respond_auth_result(g_client, p_msg, ES_AUTH_RESULT_ALLOW, false);
}


bool InstallHooks()
{
    es_return_t subscribed = ES_RETURN_ERROR;
    
    es_handler_block_t handler = ^void(es_client_t * _Nonnull, const es_message_t * _Nonnull p_msg)
    {
        if (event_handler_map.count(p_msg->event_type) > 0)
        {
            char p_datetimestring[TIME_BUF_MAX] = { 0 };
            ctime_r(&p_msg->time.tv_sec, p_datetimestring);
            
            NSLog(@"Event received at: %s", p_datetimestring);
            
            event_handler_map[p_msg->event_type](p_msg);
        }
    };
    
    es_new_client_result_t result = es_new_client(&g_client, handler);
    
    // Cache needs to be explicitly cleared between program invocations
    es_clear_cache_result_t resCache = es_clear_cache(g_client);
    if(ES_CLEAR_CACHE_RESULT_SUCCESS != resCache)
    {
        NSLog(@"Unable to clear out cache!");
        subscribed = ES_RETURN_ERROR;
    }
    
    if (result == ES_NEW_CLIENT_RESULT_SUCCESS && resCache == ES_CLEAR_CACHE_RESULT_SUCCESS)
    {
        subscribed = es_subscribe(g_client, g_subscribed_events, sizeof(g_subscribed_events)/sizeof(es_event_type_t));
        
        if (subscribed == ES_RETURN_SUCCESS)
        {
            NSLog(@"Subscription success");
        }
    }
    
    return subscribed == ES_RETURN_SUCCESS;
}

bool UninstallHooks()
{
    bool unsubscribed = es_unsubscribe(g_client, g_subscribed_events, sizeof(g_subscribed_events));
    
    bool client_deleted = es_delete_client(g_client);

    if (client_deleted)
    {
        g_client = nullptr;
    }
    
    return unsubscribed && client_deleted;
}
