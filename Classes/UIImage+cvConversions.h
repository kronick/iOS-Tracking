//
//  UIImageExtensions.h
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIImage (cvConversions)
	- (IplImage *) grayscaleIplImageRepresentation;
	- (IplImage *) IplImageRepresentation;
	- (cv::Mat) cvMatRepresentation;
	+ (UIImage *) imageWithIplImage:(IplImage *)image;
	+ (UIImage *)imageWithcvMat:(cv::Mat)mat;
@end
