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

@synthesize captureSession, capturePreview, captureVideoOutput, previewView, overlayView;
@synthesize pointTracker, objectFinder;

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
	keyPointTarget = 100;
	
	self.objectFinder = [[[Homography alloc] init] autorelease];
	
	NSDate *d = [NSDate date];
	lastTime = [d timeIntervalSinceReferenceDate];
	
	self.pointTracker = [[[PointTracker alloc] init] autorelease];
	
	// Set up the capture session
	self.captureSession = [[AVCaptureSession alloc] init];
	self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
	
	self.captureVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
	dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
	[self.captureVideoOutput setSampleBufferDelegate:self queue:queue];
	self.captureVideoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
																		forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	dispatch_release(queue);
	
	self.captureVideoOutput.minFrameDuration = CMTimeMake(1, 15);
	[NSTimer scheduledTimerWithTimeInterval:1/15. target:self selector:@selector(redrawKeyPoints:) userInfo:nil repeats:YES];
	
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
	
	[self.captureSession beginConfiguration];
	[self.captureSession addOutput:self.captureVideoOutput];
	[self.captureSession addInput:captureInput];
	[self.captureSession commitConfiguration];
	
	[self.captureSession startRunning];
	
	
	NSLog(@"Setting up preview layer...");
	// Set up the preview layer
	CALayer *viewPreviewLayer = self.previewView.layer;
	self.capturePreview = [[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession] autorelease];
	self.capturePreview.frame = self.previewView.bounds;
	self.capturePreview.videoGravity = AVLayerVideoGravityResize;
	[viewPreviewLayer addSublayer:self.capturePreview];
	
	self.overlayView = [[[OverlayView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	[self.view insertSubview:self.overlayView atIndex:1];
	
	self.overlayView.pointTracker = self.pointTracker;
	NSLog(@"View Did Load");
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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
	[self.overlayView setNeedsDisplay];
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
		FASTThreshold += (float)(mDetectedKeyPoints.size() - (float)keyPointTarget) * .1;
		if(FASTThreshold > 500) FASTThreshold = 500;
		if(FASTThreshold < 1)   FASTThreshold = 1;
	}
	mCapturedImage = cv::Mat(image);
	
	if(NO && pointTracker->tracking) {
		CGPoint pt;
		// Search in the area around each keypoint for matches to track
		for(int i=0; i<mDetectedKeyPoints.size(); i++) {
			pt.x = mDetectedKeyPoints[i].pt.x;
			pt.y = mDetectedKeyPoints[i].pt.y;
			[pointTracker checkPoint:pt inImage:&mCapturedImage];
		}
	}
	[self.pointTracker tick];
	if([self.pointTracker countActivePoints] <= keyPointTarget * .05) {
		setNewMilestone = YES;
	}
	
	[self.overlayView setKeyPoints:mDetectedKeyPoints];
	
	if(setNewMilestone && fabs(mDetectedKeyPoints.size() - keyPointTarget) < keyPointTarget * .1) {
		[self setMilestone];
		setNewMilestone = NO;
	}
	
	frameCount++;
	
	// Calculate frame rate
	NSDate *d = [NSDate date];
	double frameRate = 1 / ([d timeIntervalSinceReferenceDate] - lastTime);
	lastTime = [d timeIntervalSinceReferenceDate];
	//NSLog(@"FPS: %f with %i keypoints", frameRate, mDetectedKeyPoints.size());
}


#pragma mark -
#pragma mark IBActions

- (IBAction) setReferenceImage {
	NSLog(@"Finding matches...");
	vector<KeyPoint> sourceKeys = mDetectedKeyPoints;
	[objectFinder setSourceImage:&mMilestoneImage];
	[objectFinder setSourceKeyPoints:&mMilestoneKeyPoints];
}
- (IBAction) findReferenceImage {
	if([objectFinder sourceKeyPoints].size() > 0) {
		vector<KeyPoint> destKeys = mDetectedKeyPoints;
		[objectFinder setDestImage:&mCapturedImage];
		[objectFinder setDestKeyPoints:&destKeys];
		[objectFinder calculate];
		NSLog(@"Homography: %@", [objectFinder getArray]);
		//Mat xformed =  [objectFinder getMatrix] * (Mat_<double>(3,1) << 1,1,1);
		Mat h = [objectFinder getMatrix];
		CGPoint corners[4];
		for(int i=0; i<4; i++) {
			double x,y;
			switch(i) {
				case 0:
					x=0; y=0; break;
				case 1:
					x=mMilestoneImage.cols; y=0; break;
				case 2:
					x=mMilestoneImage.cols; y=mMilestoneImage.rows; break;
				case 3:
					x=0; y=mMilestoneImage.rows; break;
					
			}
			double Z = 1./(h.at<double>(2,0)*x + h.at<double>(2,1)*y + h.at<double>(2,2));
			double X = (h.at<double>(0,0)*x + h.at<double>(0,1)*y + h.at<double>(0,2))*Z;
			double Y = (h.at<double>(1,0)*x + h.at<double>(1,1)*y + h.at<double>(1,2))*Z;
			corners[i] = CGPointMake(X, Y);
			NSLog(@"Corner %i: (%f, %f)", i, X, Y);
		}
		
		[self.overlayView setFoundCorners:corners];
	}
}

- (IBAction) track {
	/*NSLog(@"Looking for matches...");
	NSLog(@"%i x %i", mCapturedImage.rows, mCapturedImage.cols);
	cv::SURF surf;
	surf(mReferenceImage, cv::Mat(), mReferenceKeyPoints, mReferenceDescriptor, true);
	NSLog(@"%i matches found.", mReferenceDescriptor.size());
	*/
	[NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(updateMatch:) userInfo:nil repeats:YES];
	
	setNewMilestone = YES;
}
- (void)updateMatch:(NSTimer*)theTimer {
	[self findReferenceImage];
}

- (void) setMilestone {
	pointTracker->tracking = NO;
	[pointTracker clearTrackedPoints];
	mMilestoneImage = mCapturedImage.clone(); 
	mMilestoneKeyPoints = mDetectedKeyPoints;
	CGPoint pt;
	for(int i=0; i<mMilestoneKeyPoints.size(); i++) {
		pt.x = mMilestoneKeyPoints[i].pt.x;
		pt.y = mMilestoneKeyPoints[i].pt.y;
		[pointTracker addPoint:pt inImage:&mMilestoneImage];
	}
	pointTracker->tracking = YES;
}



@end
