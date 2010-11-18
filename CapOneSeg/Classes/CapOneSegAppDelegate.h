//
//  CapOneSegAppDelegate.h
//  CapOneSeg
//
//  Created by ito on 平成22/10/15.
//  Copyright 2010 Ito. All rights reserved.
//

#import <UIKit/UIKit.h>


@class MasterViewController;
@class CapPlayerController;

@interface CapOneSegAppDelegate : NSObject <UIApplicationDelegate> {
    
    UIWindow *window;
    
    UISplitViewController *splitViewController;
    
    MasterViewController *rootViewController;
    CapPlayerController *detailViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UISplitViewController *splitViewController;
@property (nonatomic, retain) IBOutlet MasterViewController *rootViewController;
@property (nonatomic, retain) IBOutlet CapPlayerController *detailViewController;

@end
