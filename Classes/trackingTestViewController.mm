//
//  trackingTestViewController.m
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "trackingTestViewController.h"
#import "UIImage+cvConversions.h"

using namespace std;
using namespace cv;

@implementation trackingTestViewController

@synthesize captureSession, capturePreview, captureVideoOutput, previewView;
@synthesize pointTracker, objectFinder;
@synthesize glView;

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/


// Implement loadView to create a view hierarchy programmatically, without using a nib.
//- (void)loadView {
//}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
		NSLog(@"Loading view.");
	
	
	// Initialize member variables
	//mFernMatcher = cv::GenericDescriptorMatcher::create("FERN", "");
	GRID_X = 40;
	GRID_Y = 70;
	FASTThreshold = 30;
	frameCount = 0;
	setNewMilestone = NO;
	keyPointTarget = 200;
	
	self.objectFinder = [[[Homography alloc] init] autorelease];
	
	NSDate *d = [NSDate date];
	lastTime = [d timeIntervalSinceReferenceDate];
	
	self.pointTracker = [[[PointTracker alloc] init] autorelease];
	
	// Set up the capture session
	// ---------------------------------------------------------------
	self.captureSession = [[AVCaptureSession alloc] init];
	self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
	
	self.captureVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
	dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
	[self.captureVideoOutput setSampleBufferDelegate:self queue:queue];
	self.captureVideoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
																		forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	dispatch_release(queue);
	
	self.captureVideoOutput.minFrameDuration = CMTimeMake(1, 25);
	[NSTimer scheduledTimerWithTimeInterval:1/25. target:self selector:@selector(redrawKeyPoints:) userInfo:nil repeats:YES];
	
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
	
	[self.captureSession beginConfiguration];
	[self.captureSession addOutput:self.captureVideoOutput];
	[self.captureSession addInput:captureInput];
	[self.captureSession commitConfiguration];
	
	[self.captureSession startRunning];
	
	
	NSLog(@"Setting up preview layer...");
	// Set up the preview layer
	// ---------------------------------------------------------------
	CALayer *viewPreviewLayer = self.previewView.layer;
	self.capturePreview = [[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession] autorelease];
	self.capturePreview.frame = self.previewView.bounds;
	self.capturePreview.videoGravity = AVLayerVideoGravityResize;
	[viewPreviewLayer addSublayer:self.capturePreview];
	
	//self.overlayView = [[[OverlayView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	//[self.view insertSubview:self.overlayView atIndex:1];
	

	
	// Set up the OpenGL view
	// ---------------------------------------------------------------
	NSLog(@"Setting up OpenGL rendering layer...");
	self.glView = [[GLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[self.view addSubview:self.glView];
	
	NSLog(@"View Did Load");
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[self.captureSession release];
	[self.captureVideoOutput release];
}


- (void)dealloc {
    [super dealloc];
}

- (void)redrawKeyPoints:(NSTimer *)timer {
	//[self.overlayView setNeedsLayout];
	//[self.overlayView setNeedsDisplay];
}


# pragma -
# pragma mark AVCaptureVideoDataOutputSampleBufferDelegate


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	IplImage *image = [Utilities IplImageFromSampleBuffer:sampleBuffer];
	
	//vector<cv::KeyPoint> keyPoints;
	cv::FAST(image, mDetectedKeyPoints, FASTThreshold, true);
	//NSLog(@"Keypoints found: %i, Threshold: %f", mDetectedKeyPoints.size(), FASTThreshold);
	// Dynamically adjust threshold to have about 150 points
	if(fabs(mDetectedKeyPoints.size() - keyPointTarget) > keyPointTarget  * .1) {
		FASTThreshold += (float)(mDetectedKeyPoints.size() - (float)keyPointTarget) * .01;
		if(FASTThreshold > 200) FASTThreshold = 200;
		if(FASTThreshold < 1)   FASTThreshold = 1;
	}
	//NSLog(@"Threshold: %f", FASTThreshold);
	//mCapturedImage.release();
	mCapturedImage = cv::Mat(image).clone();
	cvReleaseImage(&image);
	 
	//[self.overlayView setKeyPoints:mDetectedKeyPoints];
	[self.glView setKeyPoints:mDetectedKeyPoints];
	
	if(setNewMilestone && fabs(mDetectedKeyPoints.size() - keyPointTarget) < keyPointTarget * .1) {
		[self setMilestone];
		setNewMilestone = NO;
	}
	

	[self findReferenceImage];
	
	frameCount++;
	
	//[self redrawKeyPoints:nil];
	
	// Calculate frame rate
	NSDate *d = [NSDate date];
	double frameRate = 1 / ([d timeIntervalSinceReferenceDate] - lastTime);
	lastTime = [d timeIntervalSinceReferenceDate];
	NSLog(@"FPS: %f with %i keypoints", frameRate, mDetectedKeyPoints.size());
}


#pragma mark -
#pragma mark IBActions

- (IBAction) setReferenceImage {
	NSLog(@"Finding matches...");
	[self setMilestone];
	vector<KeyPoint> sourceKeys = mDetectedKeyPoints;
	[objectFinder setSourceImage:&mMilestoneImage];
	[objectFinder setSourceKeyPoints:&mMilestoneKeyPoints];
	[objectFinder train];
	[objectFinder saveTrainingData:@"someshit.yaml.gz"];
}
- (IBAction) loadReference {
	[objectFinder loadTrainingData:@"someshit.yaml.gz"];
}
- (IBAction) findReferenceImage {
	if([objectFinder isTrained]) {	// && [objectFinder sourceKeyPoints].size() > 0
		vector<KeyPoint> destKeys = mDetectedKeyPoints;
		[objectFinder setDestImage:&mCapturedImage];
		[objectFinder setDestKeyPoints:&destKeys];
		BOOL success = [objectFinder calculate];
		
		if(success) NSLog(@"Object detected!");
		else		NSLog(@"Object not detected.");
		
		Mat h = [objectFinder getMatrix];
		CGPoint corners[4];
		for(int i=0; i<4; i++) {
			double x,y;
			switch(i) {
				case 0:
					x=0; y=0; break;
				case 1:
					x=mCapturedImage.cols; y=0; break;
				case 2:
					x=mCapturedImage.cols; y=mCapturedImage.rows; break;
				case 3:
					x=0; y=mCapturedImage.rows; break;
					
			}
			double Z = 1./(h.at<double>(2,0)*x + h.at<double>(2,1)*y + h.at<double>(2,2));
			double X = (h.at<double>(0,0)*x + h.at<double>(0,1)*y + h.at<double>(0,2))*Z;
			double Y = (h.at<double>(1,0)*x + h.at<double>(1,1)*y + h.at<double>(1,2))*Z;
			corners[i] = success ? CGPointMake(X, Y) : CGPointMake(0, 0);
		}
		
		[self.glView setFoundCorners:corners];
		[self.glView setmodelviewMatrix:[objectFinder getModelviewMatrix]];
		[self.glView setDetected:success];
	}
}

- (IBAction) track {
	[NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(updateMatch:) userInfo:nil repeats:YES];
	
	setNewMilestone = YES;
}
- (void)updateMatch:(NSTimer*)theTimer {
	[self findReferenceImage];
}

- (void) setMilestone {
	mMilestoneImage = mCapturedImage.clone(); 
	mMilestoneKeyPoints = mDetectedKeyPoints;

}



@end
