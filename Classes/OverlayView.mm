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
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextClearRect(context, self.frame);
	
	CGContextSetFillColorWithColor(context, [UIColor greenColor].CGColor);
	
	
	for(int i=0; i<mDetectedKeyPoints.size(); i++) {
		CGPoint kp = CGPointMake(mDetectedKeyPoints[i].pt.x, mDetectedKeyPoints[i].pt.y);
		kp = [self getScreenCoord:kp];
		CGContextAddRect(context, CGRectMake(kp.x, kp.y, 2, 2));
	}

	
	CGContextFillPath(context);
	
	// Draw tracking lines
    CGContextSaveGState(context);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
	
	vector<TrackedPoint *> trackedPointsToDraw = pointTracker->trackedPoints;
	CGPoint a, b;
	for(int j=0; j<trackedPointsToDraw.size(); j++) {
		
		if(trackedPointsToDraw[j] && trackedPointsToDraw[j]->active && trackedPointsToDraw[j]->age < 5) {
			/*
			for(int i=0; i<trackedPointsToDraw[j]->segments.size(); i++) {
				a = [self getScreenCoord:trackedPointsToDraw[j]->segments[i].a];
				b = [self getScreenCoord:trackedPointsToDraw[j]->segments[i].b];
				CGContextMoveToPoint(context, a.x, a.y);
				CGContextAddLineToPoint(context, b.x, b.y);
			}
			 */
			
			a = [self getScreenCoord:trackedPointsToDraw[j]->sourcePt];
			b = [self getScreenCoord:trackedPointsToDraw[j]->pt];
			CGContextMoveToPoint(context, a.x, a.y);
			CGContextAddLineToPoint(context, b.x, b.y);		
			
		}
		/*
		for(int i=0; i<pointTracker->trackedPoints[j]->segments.size(); i++) {
			a = [self getScreenCoord:pointTracker->trackedPoints[j]->segments[i].a];
			b = [self getScreenCoord:pointTracker->trackedPoints[j]->segments[i].b];
			CGContextMoveToPoint(context, a.x, a.y);
			CGContextAddLineToPoint(context, b.x, b.y);
		}
		 */
	}
	CGContextStrokePath(context);
	
	CGContextSetFillColorWithColor(context, [UIColor purpleColor].CGColor);
	for(int j=0; j<trackedPointsToDraw.size(); j++) {
		if(trackedPointsToDraw[j] && trackedPointsToDraw[j]->active && trackedPointsToDraw[j]->age < 5) {
			a = [self getScreenCoord:trackedPointsToDraw[j]->sourcePt];
			CGContextAddRect(context, CGRectMake(a.x, a.y, 5-trackedPointsToDraw[j]->age, 5-trackedPointsToDraw[j]->age));
		}
	}
	CGContextFillPath(context);

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
    CGContextRestoreGState(context);      	
	
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
	_out.x = self.frame.size.width-imgPoint.y*320/480;
	_out.y = imgPoint.x*480/640;
	return _out;
}

- (void) setFoundCorners:(CGPoint[]) corners {
	for(int i=0; i<4; i++)
		foundCorners[i] = corners[i];
}

@end
