//
//  PointTracker.h
//  trackingTest
//
//  Created by kronick on 2/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TrackedPoint.h"

typedef struct {
	int row;
	int col;
} Cell;

@interface PointTracker : NSObject {
	cv::Mat *mSourceImage;
	std::vector<std::vector<std::vector<TrackedPoint *> > > mTrackedPointGrid;	// Pointers to TrackedPoints in trackedPoints
	
	NSInteger gridX;
	NSInteger gridY;
	int maxAge;
@public
	BOOL tracking;
	std::vector<TrackedPoint *> trackedPoints;
}


- (std::vector<TrackedPoint *>) getTrackedPoints;
- (void)checkPoint:(CGPoint)point inImage:(cv::Mat *)img;	// find bucket, update trackedpoint if matched
- (void)addPoint:(CGPoint)point inImage:(cv::Mat *)img;		// adds to trackedPoints
- (Cell)getCellForPoint:(CGPoint)point inImage:(cv::Mat *)img;
- (void)clearTrackedPoints;
- (void)tick;
- (int)countActivePoints;
@end
