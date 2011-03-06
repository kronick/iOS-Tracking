//
//  TrackedPoint.mm
//  trackingTest
//
//  Created by kronick on 2/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TrackedPoint.h"


@implementation TrackedPoint


- (id)initWithPoint:(CGPoint)startPoint andImage:(cv::Mat *)otherImage {
	[super init];
	sourcePt = startPoint;
	pt = startPoint;
	sourceImage = otherImage;
	differenceThreshold = 15;
	age = 0;
	active = YES;
	return self;
}

- (BOOL)compareWithPoint:(CGPoint)other inImage:(cv::Mat *)otherImage {
	CGFloat sum = [self sumOfDifferencesWithPoint:other inImage:otherImage];
	if(sum < differenceThreshold)
		return YES;
	else
		return NO;
}
- (CGFloat)sumOfDifferencesWithPoint:(CGPoint)otherPt inImage:(cv::Mat *)otherImage {
	// Calculate Sum of Absolute Differences in an 9x9 region around the keypoints
	int w = 4;
	int numberOfPixels = 0;
	CGFloat sumOfAbsoluteDifferences = 0;
	
	if(sourcePt.x > w && otherPt.x > w && sourcePt.x < sourceImage->cols-(w+1) && otherPt.x < otherImage->cols-(w+1) &&
	   sourcePt.y > w && otherPt.y > w && sourcePt.y < sourceImage->rows-(w+1) && otherPt.y < otherImage->rows-(w+1)) { // Ignore points around the edges for now
		for(int i=-w; i<=w; i++) {
			for(int j=-w; j<=w; j++) {
				numberOfPixels++;
				sumOfAbsoluteDifferences += abs(sourceImage->data[(int)((sourcePt.x+i) + (sourcePt.y+j) * sourceImage->cols)]
												- otherImage->data[(int)((otherPt.x+i) + (otherPt.y+j) * otherImage->cols)]);
												/// sourceImage->data[(int)((sourcePt.x+i) + (sourcePt.y+j) * sourceImage->cols)]; 
			}
		}
		if(sumOfAbsoluteDifferences > 0 )
			return sumOfAbsoluteDifferences / numberOfPixels;
		else {
			//NSLog(@"PROBLEM");
			return nil;
		}
	}
	else return nil;	
}
- (CGPoint)trackAmongstPoints:(NSMutableArray *)points inImage:(cv::Mat *)otherImage {
	// Returns weighted avg of all found points, may be unnecessary
	return CGPointMake(0, 0);
}
- (void)setNewPoint:(CGPoint)newPoint {
	// Insert segment, update pt
	Segment _s;
	_s.a = pt;
	_s.b = newPoint;
	segments.push_back(_s);
	pt = newPoint;
	age = 0;
}

- (std::vector<Segment>) getSegments {
	return segments;
}

- (void)tick {
	age++;
}

@end
