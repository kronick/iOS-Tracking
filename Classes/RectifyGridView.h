//
//  RectifyGridView.h
//  trackingTest
//
//  Created by kronick on 6/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PointTracker.h"

@interface RectifyGridView : UIView {

@public
	CGPoint corners[4];
}

@property (nonatomic,retain) PointTracker *pointTracker;

- (void) setCorner:(int)cornerIndex toPoint:(CGPoint)point;
@end

