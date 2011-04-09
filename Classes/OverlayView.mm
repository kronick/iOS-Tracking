//
//  overlayView.mm
//  trackingTest
//
//  Created by kronick on 1/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "OverlayView.h"

@implementation OverlayView

@synthesize pointTracker;

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
		// Initialize member variables
		mDetectedKeyPoints = std::vector<cv::KeyPoint>();
		
		// Make this a transparent layer
		self.backgroundColor = [UIColor clearColor];
		
		for(int i=0; i<4; i++)
			foundCorners[i] = CGPointMake(0, 0);
		
		screenWidth = [[UIScreen mainScreen] bounds].size.width;
		screenHeight = [[UIScreen mainScreen] bounds].size.height;
		
		foundSource = NO;
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextClearRect(context, self.frame);
	
	// Draw keypoints
	CGContextSetFillColorWithColor(context, [UIColor greenColor].CGColor);
	for(int i=0; i<mDetectedKeyPoints.size(); i++) {
		CGPoint kp = CGPointMake(mDetectedKeyPoints[i].pt.x, mDetectedKeyPoints[i].pt.y);
		kp = [self getScreenCoord:kp];
		CGContextAddRect(context, CGRectMake(kp.x, kp.y, 2, 2));
	}
	CGContextFillPath(context);
	
	/*
	// Draw tracking lines
    CGContextSaveGState(context);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
	
	vector<TrackedPoint *> trackedPointsToDraw = pointTracker->trackedPoints;
	CGPoint a, b;
	for(int j=0; j<trackedPointsToDraw.size(); j++) {
		
		if(trackedPointsToDraw[j] && trackedPointsToDraw[j]->active && trackedPointsToDraw[j]->age < 5) {
			a = [self getScreenCoord:trackedPointsToDraw[j]->sourcePt];
			b = [self getScreenCoord:trackedPointsToDraw[j]->pt];
			CGContextMoveToPoint(context, a.x, a.y);
			CGContextAddLineToPoint(context, b.x, b.y);		
			
		}
	}
	CGContextStrokePath(context);
	*/
	 
	if(foundSource) {
		CGPoint a, b;
		// Draw found object
		CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
		CGContextSetLineWidth(context, 3.0);
		for(int i=0; i<4; i++) {
			a = [self getScreenCoord:foundCorners[i]];
			b = [self getScreenCoord:foundCorners[(i+1)%4]];
			CGContextMoveToPoint(context, a.x, a.y);
			CGContextAddLineToPoint(context, b.x, b.y);		
		}
		CGContextStrokePath(context);     	
	}
	
	//CGContextRelease(context);
	
}


- (void)dealloc {
    [super dealloc];
}

- (void) setKeyPoints:(std::vector<cv::KeyPoint>) newKeyPoints {
	mDetectedKeyPoints = newKeyPoints;
}

- (CGPoint) getScreenCoord:(CGPoint)imgPoint {
	CGPoint _out;
	// MAGIC NUMBERS ALERT
	_out.x = self.frame.size.width-imgPoint.y*screenWidth/480;
	_out.y = imgPoint.x*screenHeight/640;
	return _out;
}

- (void) setFoundCorners:(CGPoint[]) corners {
	for(int i=0; i<4; i++)
		foundCorners[i] = corners[i];
}

- (void) setFoundSource:(BOOL)b {
	foundSource = b;
}

@end
