//
//  TrackedPoint.h
//  trackingTest
//
//  Created by kronick on 2/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


typedef struct {
	CGPoint a;
	CGPoint b;
} Segment;

@interface TrackedPoint : NSObject {
@public
	cv::Mat *sourceImage;
	std::vector<Segment> segments;
	CGFloat differenceThreshold;
	CGPoint pt;
	CGPoint sourcePt;	
	int age;
	BOOL active;
}

- (id)initWithPoint:(CGPoint)startPoint andImage:(cv::Mat *)startImage;
- (BOOL)compareWithPoint:(CGPoint)other inImage:(cv::Mat *)otherImage;
- (CGFloat)sumOfDifferencesWithPoint:(CGPoint)other inImage:(cv::Mat *)otherImage;
- (CGPoint)trackAmongstPoints:(NSMutableArray *)points inImage:(cv::Mat *)otherImage;	// Returns weighted avg of all found points, may be unnecessary
- (void)setNewPoint:(CGPoint)newPoint;	// Insert segment, update pt

- (std::vector<Segment>) getSegments;
- (void) tick;
@end
