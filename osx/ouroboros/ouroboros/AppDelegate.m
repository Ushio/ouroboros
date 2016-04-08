//
//  AppDelegate.m
//  ouroboros
//
//  Created by Nakazi_w0w on 4/8/16.
//  Copyright © 2016 wow. All rights reserved.
//

#import "AppDelegate.h"

static void show_alert(NSString *message) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert runModal];
}
@interface AppCommand : NSObject
@property (nonatomic) NSString *location;
@property (nonatomic) BOOL top;
@end
@implementation AppCommand
@end

@implementation AppDelegate {
    NSMutableArray<AppCommand *> *_commands;
    NSTimer *_timer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _commands = [[NSMutableArray alloc] init];
    
//    NSArray *runnings = [[NSWorkspace sharedWorkspace] runningApplications];
//    for(NSRunningApplication *app in runnings) {
//        NSLog(@"%@, %@", app.bundleURL.path, app.isActive ? @"active" : @"back");
//    }
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSString *appDir = [appPath stringByDeletingLastPathComponent];
    NSString *jsonPath = [appDir stringByAppendingPathComponent:@"ouroboros.json"];
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];
    if(data == nil) {
        show_alert(@"ouroboros.json is not found");
        exit(0);
    }
    NSError *e;
    NSArray *commands = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
    if([commands isKindOfClass:[NSArray class]] == NO) {
        show_alert(@"ouroboros.json's root is not array");
        exit(0);
        return;
    }
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(update:) userInfo:nil repeats:YES];
    
    // 起動プロセス
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for(NSDictionary *command in commands) {
            if([command isKindOfClass:[NSDictionary class]] == false) {
                continue;
            }
            BOOL commandHandled = NO;
            
            NSNumber *delay = command[@"delay"];
            if(delay && [delay isKindOfClass:[NSNumber class]]) {
                [NSThread sleepForTimeInterval:delay.doubleValue];
                commandHandled = YES;
            }
            
            NSString *run_location = command[@"run"];
            if(run_location && [run_location isKindOfClass:[NSString class]]) {
                NSNumber *top = command[@"top"];
                AppCommand *command = [[AppCommand alloc] init];
                command.location = run_location;
                command.top = [top isKindOfClass:[NSNumber class]] ? top.boolValue : NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_commands addObject:command];
                    
                    if(command.top) {
                        // すでに起動していたら、アクティベートだけはする
                        NSArray *runnings = [[NSWorkspace sharedWorkspace] runningApplications];
                        for(NSRunningApplication *app in runnings) {
                            if([app.bundleURL.path isEqualToString:command.location]) {
                                [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                                break;
                            }
                        }
                    }
                });
                commandHandled = YES;
            }
            
            if(commandHandled == NO) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    show_alert([NSString stringWithFormat:@"command is invalid: %@", command]);
                });
            }
        }
    });
}

- (void)update:(id)sender {
    NSArray *runnings = [[NSWorkspace sharedWorkspace] runningApplications];
    
    BOOL isSelfActive = [NSRunningApplication currentApplication].isActive;
    
    for(AppCommand *command in _commands) {
        BOOL isLaunch = NO;
        for(NSRunningApplication *app in runnings) {
            if([app.bundleURL.path isEqualToString:command.location]) {
                isLaunch = YES;
                
                if(command.top && app.isActive == NO && isSelfActive == NO) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                    });
                }
                
                break;
            }
        }
        if(isLaunch == NO) {
            [[NSWorkspace sharedWorkspace] launchApplication:command.location];
        }
    }
}

@end
