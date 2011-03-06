//
//  Utilities.h
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <arm_neon.h>


@interface Utilities : NSObject {

}

+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;
+ (IplImage *)IplImageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;
+ (CGImageRef) cgImageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;

void neon_convert(uint8_t * __restrict dest, uint8_t * __restrict src, int numPixels);

@end