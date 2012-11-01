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
		
		[self loadTextureNamed:@"overlay-textures-03.png" intoSlot:3];
		[self loadTextureNamed:@"overlay-textures-02.png" intoSlot:2];
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

- (void) loadTextureNamed: (NSString *)filename intoSlot: (int)slotNumber {
	NSString *path = [[NSBundle mainBundle] pathForResource:[filename stringByDeletingPathExtension] ofType:[filename pathExtension]];
    NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
    UIImage *image = [[UIImage alloc] initWithData:texData];
    if (image == nil)
        NSLog(@"Could not load image from resource: %@ at path %@", filename, path);
	
    GLuint width = CGImageGetWidth(image.CGImage);
    GLuint height = CGImageGetHeight(image.CGImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(height * width * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, CGRectMake(0, 0, width, height));
    CGContextTranslateCTM(context, 0, height);
	CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
	
    m_renderingEngine->setTexture(slotNumber, imageData, width, height);
	
    CGContextRelease(context);
    free(imageData);
    [image release];
    [texData release];	
}

- (void) setScale: (CGFloat) scale {
	m_renderingEngine->scale = scale;
}
- (void) translate:(CGPoint)dP {
	dP.x *= .001;
	dP.y *= .001;
	m_renderingEngine->translation.x += dP.y;
	m_renderingEngine->translation.y += dP.x;
}
@end
