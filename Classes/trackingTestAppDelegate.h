//
//  trackingTestAppDelegate.h
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class trackingTestViewController;

@interface trackingTestAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    trackingTestViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet trackingTestViewController *viewController;

@end

