//
//  GLView.mm
//  trackingTest
//
//  Created by kronick on 4/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GLView.h"
#import "mach/mach_time.h"
#import <OpenGLES/ES2/gl.h> // For GL_RENDERBUFFER

@implementation GLView
+ (Class) layerClass {
	return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
		CAEAGLLayer* eaglLayer = (CAEAGLLayer*)super.layer;
		eaglLayer.opaque = NO;	// Change this when the camera image is drawn as part of this rendering context
		self.userInteractionEnabled = NO;
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		if(!context || ![EAGLContext setCurrentContext:context]) {
			[self release];
			return nil;
		}
		
		m_renderingEngine = new OverlayRenderer();
		
		[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:eaglLayer];
		
		m_renderingEngine->Initialize(CGRectGetWidth(frame), CGRectGetHeight(frame));
		
		[self drawView:nil];
		m_timestamp = CACurrentMediaTime();
		CADisplayLink* displayLink;
		displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawView:)];
		[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void) didRotate:(NSNotification *)notification {
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	m_renderingEngine->OnRotate((DeviceOrientation) orientation);
	[self drawView:nil];
}

- (void) drawView: (CADisplayLink*) displayLink {
	if(displayLink != nil) {
		float elapsedSeconds = displayLink.timestamp - m_timestamp;
		m_timestamp = displayLink.timestamp;
		m_renderingEngine->UpdateAnimation(elapsedSeconds);
	}
	
	m_renderingEngine->Render();

	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)dealloc {
	if([EAGLContext currentContext] == context)
		[EAGLContext setCurrentContext:nil];
	
	[context release];
    [super dealloc];
}


- (void) setKeyPoints:(std::vector<cv::KeyPoint>) newKeyPoints {
	m_renderingEngine->setKeypoints(newKeyPoints);
}
- (void) setFoundCorners:(CGPoint[]) corners {
	m_renderingEngine->setCorners(corners);
}
- (void) setmodelviewMatrix:(cv::Mat) matrix {
	m_renderingEngine->setModelviewMatrix(matrix);
}
- (void) setDetected:(BOOL)detected {
	m_renderingEngine->setDrawOverlay(detected ? true : false);
}

@end
