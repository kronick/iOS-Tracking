//
//  Utilities.m
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Utilities.h"
#import <AVFoundation/AVFoundation.h>
//#import "arm_neon_gcc.h"

@implementation Utilities

+ (IplImage *) IplImageFromSampleBuffer: (CMSampleBufferRef) sampleBuffer {
	// IplImage is the image data structure used by OpenCV
	// CV prefix (capitalized) is CoreVideo
	// cv prefix (lowercase) is OpenCV
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer,0);
	
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
	IplImage *iplimage = cvCreateImage(cvSize(width, height), IPL_DEPTH_8U, 4);
	iplimage->imageData = (char *)baseAddress;
	iplimage->widthStep = bytesPerRow;


	unsigned int downSample = 1;
	
	IplImage *ret = cvCreateImage(cvSize(width/downSample, height/downSample), IPL_DEPTH_8U, 1);
	
	/*
	//cvCvtColor(iplimage, ret, CV_RGBA2GRAY);
	
	
	unsigned int *intImagePointer = (unsigned int *)iplimage->imageData;
	unsigned int fourBytes;
	
	
	for(int j=0; j<height / downSample; j++) {
		for(int i=0; i<width / downSample; i++) {
			fourBytes = intImagePointer[width * j * downSample + i * downSample];
			ret->imageData[width / downSample * j + i] = ((unsigned char)fourBytes>>(2*8)) + ((unsigned char)fourBytes>>(1*8)) + ((unsigned char)fourBytes>>(0*8));
		}
	}
	 */
	
	neon_convert((uint8_t *)ret->imageData, (uint8_t *)iplimage->imageData, width/downSample*height/downSample);
	cvReleaseImage(&iplimage);
	
	//CGImageRelease(cgImage);
	
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	return ret;
}


+ (CGImageRef) cgImageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer,0);
	
    // Get the number of bytes per row for the pixel buffer.
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height.
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
	
    // Create a device-dependent RGB color space.
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
		if (colorSpace == NULL) {
            // Handle the error appropriately.
            return nil;
        }
    }
	
    // Get the base address of the pixel buffer.
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
	
    // Create a Quartz direct-access data provider that uses data we supply.
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    // Create a bitmap image from data supplied by the data provider.
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow,
									   colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
									   dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
	

	// REMEMBER TO RELEASE THE CG IMAGE THAT IS RETURNED
    //CGImageRelease(cgImage);
	
    //CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
	return cgImage;
}

+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer,0);
	
    // Get the number of bytes per row for the pixel buffer.
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height.
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
	
    // Create a device-dependent RGB color space.
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
		if (colorSpace == NULL) {
            // Handle the error appropriately.
            return nil;
        }
    }
	
    // Get the base address of the pixel buffer.
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
	
    // Create a Quartz direct-access data provider that uses data we supply.
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    // Create a bitmap image from data supplied by the data provider.
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow,
									   colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
									   dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
	
    // Create and return an image object to represent the Quartz image.
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
	
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
    return image;
}


void neon_convert (uint8_t * __restrict dest, uint8_t * __restrict src, int numPixels)
{
	// From http://computer-vision-talks.com/2011/02/a-very-fast-bgra-to-grayscale-conversion-on-iphone/
	
	int i;
	uint8x8_t rfac = vdup_n_u8 (77);
	uint8x8_t gfac = vdup_n_u8 (151);
	uint8x8_t bfac = vdup_n_u8 (28);
	int n = numPixels / 8;
	
	// Convert per eight pixels
	for (i=0; i<n; ++i)
	{
		uint16x8_t  temp;
		uint8x8x4_t rgb  = vld4_u8 (src);
		uint8x8_t result;
		
		temp = vmull_u8 (rgb.val[0],      bfac);
		temp = vmlal_u8 (temp,rgb.val[1], gfac);
		temp = vmlal_u8 (temp,rgb.val[2], rfac);
		
		result = vshrn_n_u16 (temp, 8);
		vst1_u8 (dest, result);
		src  += 8*4;
		dest += 8;
	}
	 
	/*
	asm volatile("lsr          %2, %2, #3      \n"
				 "# build the three constants: \n"
				 "mov         r4, #28          \n" // Blue channel multiplier
				 "mov         r5, #151         \n" // Green channel multiplier
				 "mov         r6, #77          \n" // Red channel multiplier
				 "vdup.8      d4, r4           \n"
				 "vdup.8      d5, r5           \n"
				 "vdup.8      d6, r6           \n"
				 ".loop:                       \n"
				 "# load 8 pixels:             \n"
				 "vld4.8      {d0-d3}, [%1]!   \n"
				 "# do the weight average:     \n"
				 "vmull.u8    q7, d0, d4       \n"
				 "vmlal.u8    q7, d1, d5       \n"
				 "vmlal.u8    q7, d2, d6       \n"
				 "# shift and store:           \n"
				 "vshrn.u16   d7, q7, #8       \n" // Divide q3 by 256 and store in the d7
				 "vst1.8      {d7}, [%0]!      \n"
				 "subs        %2, %2, #1       \n" // Decrement iteration count
				 "bne         .loop            \n" // Repeat unil iteration count is not zero
				 :
				 : "r"(dest), "r"(src), "r"(numPixels)
				 : "r4", "r5", "r6"
				 );	
	 */
}


@end
