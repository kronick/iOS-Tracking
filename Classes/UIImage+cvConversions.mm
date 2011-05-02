//
//  UIImageExtensions.m
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "UIImage+cvConversions.h"


@implementation UIImage (cvConversions)


// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)IplImageRepresentation {
	CGImageRef imageRef = self.CGImage;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(self.size.width, self.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, self.size.width, self.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);
	
	return ret;
}

- (cv::Mat) cvMatRepresentation {
	IplImage *ipl = [self IplImageRepresentation];
	cv::Mat outMat(ipl);
	cvReleaseImage(&ipl);
	return outMat;
}

- (IplImage *)grayscaleIplImageRepresentation {
	CGImageRef imageRef = self.CGImage;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(self.size.width, self.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, self.size.width, self.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 1);
	cvCvtColor(iplimage, ret, CV_RGBA2GRAY);
	cvReleaseImage(&iplimage);
	
	return ret;
}

+ (UIImage *)imageWithcvMat:(cv::Mat)mat {
	IplImage ipl = mat;
	return [UIImage imageWithIplImage:&ipl];
}

// NOTE You should convert color mode as RGB before passing to this function
+ (UIImage *)imageWithIplImage:(IplImage *)image {
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}
@end
