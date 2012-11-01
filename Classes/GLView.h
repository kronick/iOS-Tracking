//
//  GLView.h
//  trackingTest
//
//  Created by kronick on 4/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OverlayRenderer.hpp"
#import <OpenGLES/EAGL.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@interface GLView : UIView {
	EAGLContext *context;
	OverlayRenderer* m_renderingEngine;
	float m_timestamp;
	
	std::vector<cv::KeyPoint> m_detectedKeyPoints;
}

- (void) setKeyPoints:(std::vector<cv::KeyPoint>) newKeyPoints;
- (void) setFoundCorners:(CGPoint[]) corners;
- (void) setmodelviewMatrix:(cv::Mat) matrix;
- (void) setDetected:(BOOL)detected;

- (void) drawView: (CADisplayLink*) displayLink;
- (void) didRotate: (NSNotification*) notification;

- (void) loadTextureNamed: (NSString *)filename intoSlot: (int)slotNumber;

- (void) setScale: (CGFloat) scale;
- (void) translate: (CGPoint) dP;
@end
