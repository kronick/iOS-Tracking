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
@synthesize glView, statusView;
@synthesize motionManager, referenceAttitude;
@synthesize visionTrackingSwitch, gyroTrackingSwitch;
@synthesize framerateLabel, foundPointsLabel;
@synthesize imageTaggerView;

#pragma mark Lifecycle
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
	
	
	// Set up the kalman pose filter
	// -----------------------------
	// TODO: Convert this to quaternions
	poseFilter = PoseFilter();	// Use defaults
	poseInitialized = NO;
	
	[NSTimer scheduledTimerWithTimeInterval:1/60. target:self selector:@selector(updateSensorPose:) userInfo:nil repeats:YES];
	
	NSDate *d = [NSDate date];
	lastTime = [d timeIntervalSinceReferenceDate];
	
	self.pointTracker = [[[PointTracker alloc] init] autorelease];
		
	
	// Set up Core Motion services
	if(self.motionManager == nil) {
		self.motionManager = [[CMMotionManager alloc] init];
	}
	
	motionManager.deviceMotionUpdateInterval = 0.01;
	[motionManager startDeviceMotionUpdates];
	gyroTrackingOn = YES;
	
	// Set up gestures	
	UIPinchGestureRecognizer *pinchGestureRecognizer = [[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)] autorelease];
	pinchGestureRecognizer.delegate = self;
	[[self view] addGestureRecognizer:pinchGestureRecognizer];
	UIPanGestureRecognizer *panGestureRecognizer = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)] autorelease];
	panGestureRecognizer.delegate = self;
	[[self view] addGestureRecognizer:panGestureRecognizer];

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
	[self pauseCaptureSession];
	self.captureSession = nil;
	self.captureVideoOutput = nil;
	//	[self.captureSession release];
}

- (void)viewWillAppear:(BOOL)animated {
	NSLog(@"Resuming...");
	[self resumeCaptureSession];
}
- (void)viewWillDisappear:(BOOL)animated {
	NSLog(@"Pausing...");
	[self pauseCaptureSession];
}


- (void)dealloc {
    [super dealloc];
}

- (void)redrawKeyPoints:(NSTimer *)timer {
	//[self.overlayView setNeedsLayout];
	//[self.overlayView setNeedsDisplay];
}


# pragma -
#pragma mark ImageTaggerDelegate
- (void)setTrainingImage:(cv::Mat *)imageMat {
	//cv::Mat resizedImage;
	cv::Mat grayImage;
	//cv::resize(*imageMat, resizedImage, cv::Size(640,480),0,0, INTER_LINEAR);
	cv::cvtColor(*imageMat, grayImage, CV_BGR2GRAY);
	
	cv::FAST(grayImage, mDetectedKeyPoints, FASTThreshold, true);
	// Dynamically adjust threshold 
	int n=0;
	while(fabs(mDetectedKeyPoints.size() - keyPointTarget) > keyPointTarget  * .1 && n++ < 500) {
		FASTThreshold += (float)(mDetectedKeyPoints.size() - (float)keyPointTarget) * .01;
		if(FASTThreshold > 200) FASTThreshold = 200;
		if(FASTThreshold < 1)   FASTThreshold = 1;
		cv::FAST(grayImage, mDetectedKeyPoints, FASTThreshold, true);
	}
	
	NSLog(@"Keypoints in training image: %i", mDetectedKeyPoints.size());
	
	mCapturedImage = grayImage;
	
	[self setReferenceImage];
}
# pragma mark AVCaptureVideoDataOutputSampleBufferDelegate


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	IplImage *image = [Utilities IplImageFromSampleBuffer:sampleBuffer];
	
	//vector<cv::KeyPoint> keyPoints;
	cv::FAST(image, mDetectedKeyPoints, FASTThreshold, true);
	//NSLog(@"Keypoints found: %i, Threshold: %f", mDetectedKeyPoints.size(), FASTThreshold);
	// Dynamically adjust threshold 
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
	

	if(visionTrackingOn)
		[self findReferenceImage];
	
	frameCount++;
	
	//[self redrawKeyPoints:nil];
	
	// Calculate frame rate
	NSDate *d = [NSDate date];
	double frameRate = 1 / ([d timeIntervalSinceReferenceDate] - lastTime);
	lastTime = [d timeIntervalSinceReferenceDate];
	//NSLog(@"FPS: %f with %i keypoints", frameRate, mDetectedKeyPoints.size());
	[framerateLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%3.1f FPS", frameRate] waitUntilDone:YES];
	[foundPointsLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%i points", mDetectedKeyPoints.size()] waitUntilDone:YES];
	[framerateLabel.superview setNeedsLayout];
	[foundPointsLabel.superview setNeedsDisplay];
}

- (void)pauseCaptureSession {
	[self.captureSession stopRunning];
	self.capturePreview = nil;
	//[self.glView removeFromSuperview];
}

- (void)resumeCaptureSession {
	// Set up the capture session
	// ---------------------------------------------------------------
	self.captureSession = [[[AVCaptureSession alloc] init] autorelease];
	self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
	
	self.captureVideoOutput = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
	dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
	[self.captureVideoOutput setSampleBufferDelegate:self queue:queue];
	self.captureVideoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
																		forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	dispatch_release(queue);
	
	self.captureVideoOutput.minFrameDuration = CMTimeMake(1, 25);
	[NSTimer scheduledTimerWithTimeInterval:1/25. target:self selector:@selector(redrawKeyPoints:) userInfo:nil repeats:YES];
	visionTrackingOn = YES;
	visionTargetFound = NO;
	
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
	
	[self.captureSession beginConfiguration];
	[self.captureSession addOutput:self.captureVideoOutput];
	[self.captureSession addInput:captureInput];
	[self.captureSession commitConfiguration];
	
	NSLog(@"Setting up preview layer...");
	// Set up the preview layer
	// ---------------------------------------------------------------
	CALayer *viewPreviewLayer = self.previewView.layer;
	self.capturePreview = [[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession] autorelease];
	self.capturePreview.frame = self.previewView.bounds;
	self.capturePreview.videoGravity = AVLayerVideoGravityResize;
	[viewPreviewLayer addSublayer:self.capturePreview];
	
	// Set up the OpenGL view
	// ---------------------------------------------------------------
	NSLog(@"Setting up OpenGL rendering layer...");
	self.glView = [[[GLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	[self.view insertSubview:self.glView atIndex:1];
	

	[self.captureSession startRunning];
}

#pragma mark -
#pragma mark IBActions

- (IBAction) visionSwitchChanged {	
	visionTrackingOn = self.visionTrackingSwitch.on;	
}
- (IBAction) gyroSwitchChanged {	
	gyroTrackingOn = self.gyroTrackingSwitch.on;	
}

- (IBAction) launchImageTagger {
	//[self pauseCaptureSession];
	keyPointTarget = 200;
	if(self.imageTaggerView == nil) {
		self.imageTaggerView = [[[ImageTaggerViewController alloc] initWithNibName:@"ImageTaggerViewController" bundle:nil] autorelease];
		self.imageTaggerView.delegate = self;
	}
	
	[self presentModalViewController:self.imageTaggerView animated:YES];
}

- (IBAction) setReferenceImage {
	NSLog(@"Finding matches...");
	[self.statusView setHidden:NO];
	[self.statusView setBackgroundColor:[UIColor yellowColor]];
	
	[self setMilestone];
	vector<KeyPoint> sourceKeys = mDetectedKeyPoints;
	[objectFinder setSourceImage:&mMilestoneImage];
	[objectFinder setSourceKeyPoints:&mMilestoneKeyPoints];
	[objectFinder train];
	[objectFinder saveTrainingData:@"someshit.xml"];
	keyPointTarget = 500;
	[self.statusView setBackgroundColor:[UIColor greenColor]];
}
- (IBAction) loadReference {
	[self.statusView setHidden:NO];
	[self.statusView setBackgroundColor:[UIColor yellowColor]];
	[objectFinder loadTrainingData:@"someshit.xml"];
	[self.statusView setBackgroundColor:[UIColor greenColor]];
	keyPointTarget = 500;
}
- (IBAction) findReferenceImage {
	//visionTargetFound = NO;
	if([objectFinder isTrained] || true) {	// && [objectFinder sourceKeyPoints].size() > 0
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
			Mat P = (Mat_<double>(3,1) << x, y, 1);
			//Mat P = (Mat_<double>(3,1) << x, y, 1);
			P = h * P;
			double W = P.at<double>(2,0);
			double X = P.at<double>(0,0) / W;
			double Y = P.at<double>(1,0) / W;
			
			corners[i] = success ? CGPointMake(X, Y) : CGPointMake(0, 0);
		}
		
		if(success) {
			visionTargetFound = YES;
			Mat M = [objectFinder getModelviewMatrix];
			M = M.inv();			// Invert to get camera pose relative to found marker (*)

			if(motionManager.deviceMotion != nil) {
				self.referenceAttitude = motionManager.deviceMotion.attitude;
				referenceAttitudeMatrixTarget = (Mat_<float>(3,3) <<
													referenceAttitude.rotationMatrix.m11, referenceAttitude.rotationMatrix.m12, referenceAttitude.rotationMatrix.m13, 
													referenceAttitude.rotationMatrix.m21, referenceAttitude.rotationMatrix.m22, referenceAttitude.rotationMatrix.m23, 
													referenceAttitude.rotationMatrix.m31, referenceAttitude.rotationMatrix.m32, referenceAttitude.rotationMatrix.m33);
				referenceRotationMatrixTarget = (Mat_<float>(3,3) << M.at<float>(0,0), M.at<float>(0,1), M.at<float>(0,2),
													M.at<float>(1,0), M.at<float>(1,1), M.at<float>(1,2),
													M.at<float>(2,0), M.at<float>(2,1), M.at<float>(2,2));
				if(!poseInitialized) {
					referenceRotationMatrix = referenceRotationMatrixTarget;
					referenceAttitudeMatrix = referenceAttitudeMatrixTarget;
				}
					
				poseInitialized = YES;
				
			}
			
			visionEstimate = M;
			
			[self.glView setFoundCorners:corners];
			//[self.glView setmodelviewMatrix:M];
			 
		}
		else {
			visionTargetFound = NO;
		}
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


- (void) updateSensorPose:(NSTimer *)theTimer {
	if(poseInitialized) {
		// Respond to CMDeviceMotion data
		CMAttitude *currentAttitude = motionManager.deviceMotion.attitude;
		
		// Smooth reference rotation matrix
		
		float smooth = .5; // 0.05
		for(int i=0;i<3; i++) {
			for(int j=0; j<3; j++) {
				float dist = (referenceAttitudeMatrixTarget.at<float>(i,j)-referenceAttitudeMatrix.at<float>(i,j));
				//referenceAttitudeMatrix.at<float>(i,j) += 1 * dist * abs(dist);
				referenceAttitudeMatrix.at<float>(i,j) += smooth * dist;
				dist = (referenceRotationMatrixTarget.at<float>(i,j)-referenceRotationMatrix.at<float>(i,j));
				//referenceRotationMatrix.at<float>(i,j) += 1 * dist * abs(dist);
				referenceRotationMatrix.at<float>(i,j) += smooth * dist;
			}
		}
		
		
		CMRotationMatrix deviceR = currentAttitude.rotationMatrix;
		
		cv::Mat rotationMatrix = (Mat_<float>(3,3) <<	deviceR.m11 , deviceR.m21, deviceR.m31,
								  deviceR.m12 , deviceR.m22, deviceR.m32,
								  deviceR.m13 , deviceR.m23, deviceR.m33);
		
		rotationMatrix =  referenceAttitudeMatrix * rotationMatrix;	// referenceAltitudeMatrix is already inverted... convenient or confusing?
		
		cv::Mat rotate90 = (Mat_<float>(3,3) << 0,1,0,
												1,0,0,
												0,0,1);
							
		cv::Mat flipX = (Mat_<float>(3,3) <<	-1,0,0,
												 0,1,0,
												 0,0,-1);
		
		
		rotationMatrix = rotationMatrix.t();
		rotationMatrix = flipX * rotationMatrix * flipX;
		rotationMatrix = rotate90 * rotationMatrix;
		rotationMatrix = rotationMatrix.t();
		
		rotationMatrix = rotate90 * rotationMatrix;
		rotationMatrix = referenceRotationMatrix * rotationMatrix;
	
		Mat poseEstimate;
	
		if(visionTargetFound && visionTrackingOn) {
			poseFilter.setCameraCovariance(0.002);
			poseFilter.Correct((Mat_<float>(12,1) <<	visionEstimate.at<float>(0,3), visionEstimate.at<float>(1,3), visionEstimate.at<float>(2,3),
											   visionEstimate.at<float>(0,0), visionEstimate.at<float>(0,1), visionEstimate.at<float>(0,2),
											   visionEstimate.at<float>(1,0), visionEstimate.at<float>(1,1), visionEstimate.at<float>(1,2),
											   visionEstimate.at<float>(2,0), visionEstimate.at<float>(2,1), visionEstimate.at<float>(2,2)),
											  CAMERA_POSE, [NSDate timeIntervalSinceReferenceDate]);
			poseFilter.setGyrosCovariance(0.05);
			
			poseEstimate = poseFilter.Predict([NSDate timeIntervalSinceReferenceDate]);
			//NSLog(@"Using vision.");
		}
		else {
			poseFilter.setGyrosCovariance(0.000001);
			//NSLog(@"NOT using vision.");
		}
		
		
		if(gyroTrackingOn) {
			poseFilter.Correct((Mat_<float>(9,1) << rotationMatrix.at<float>(0,0) , rotationMatrix.at<float>(0,1) , rotationMatrix.at<float>(0,2),
												rotationMatrix.at<float>(1,0) , rotationMatrix.at<float>(1,1) , rotationMatrix.at<float>(1,2),
												rotationMatrix.at<float>(2,0) , rotationMatrix.at<float>(2,1) , rotationMatrix.at<float>(2,2)),
											GYRO_POSE, [NSDate timeIntervalSinceReferenceDate]);
			poseEstimate = poseFilter.Predict([NSDate timeIntervalSinceReferenceDate]);
		}
		
		
		/*
		if(gyroTrackingOn) {
			Mat errorMatrix = (Mat_<float>(15,1) << 0,0,0,0,0,0,
													rotationMatrix.at<float>(0,0) , rotationMatrix.at<float>(0,1) , rotationMatrix.at<float>(0,2),
													rotationMatrix.at<float>(1,0) , rotationMatrix.at<float>(1,1) , rotationMatrix.at<float>(1,2),
													rotationMatrix.at<float>(2,0) , rotationMatrix.at<float>(2,1) , rotationMatrix.at<float>(2,2));
			errorMatrix -= (Mat_<float>(15,1) << 0,0,0,0,0,0,
												poseEstimate.at<float>(6,0), poseEstimate.at<float>(7,0), poseEstimate.at<float>(8,0),
												poseEstimate.at<float>(9,0), poseEstimate.at<float>(10,0), poseEstimate.at<float>(11,0),
												poseEstimate.at<float>(12,0), poseEstimate.at<float>(13,0), poseEstimate.at<float>(14,0));
			
			Mat correctedState = poseEstimate + (errorMatrix * 0.01f);
			poseFilter.Correct((Mat_<float>(9,1) << correctedState.at<float>(6,0) , correctedState.at<float>(7,0) , correctedState.at<float>(8,0),
													correctedState.at<float>(9,0) , correctedState.at<float>(10,0) , correctedState.at<float>(11,0),
													correctedState.at<float>(12,0) , correctedState.at<float>(13,0) , correctedState.at<float>(14,0)),
							   GYRO_POSE, [NSDate timeIntervalSinceReferenceDate]);
			
			poseEstimate = poseFilter.Predict([NSDate timeIntervalSinceReferenceDate]);
		}
		 */
		//Mat poseEstimate = poseFilter.Predict((float)[NSDate timeIntervalSinceReferenceDate]);


		if(poseEstimate.data) {
			Mat M = Mat(4,4, CV_32F);
			for(int i=0; i<poseEstimate.rows; i++) {
				if(i < 3)		M.at<float>(i,3) = poseEstimate.at<float>(i,0);					// Translation components
				else if(i>5)	M.at<float>((int)i/3 - 2, i%3) = poseEstimate.at<float>(i,0);	// Rotation components
			}
			M.at<float>(3,0) = 0;
			M.at<float>(3,1) = 0;
			M.at<float>(3,2) = 0;
			M.at<float>(3,3) = 1;
			M = M.inv();			// Convert from filter frame of reference to modelview frame of reference
			[self.glView setmodelviewMatrix:M];
		}
	}
}

#pragma mark UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	return (![touch.view isKindOfClass:[UIButton class]] && ![touch.view.superview isKindOfClass:[UIToolbar class]] && ![touch.view isKindOfClass:[UIToolbar class]]);
}

- (void)handlePinch:(UIPinchGestureRecognizer *)sender {
	static CGFloat scale = 1;
	static CGFloat lastScale = sender.scale;
	if(sender.state != UIGestureRecognizerStateBegan)
		scale *= sender.scale / lastScale;
	
	lastScale = sender.scale;
	[self.glView setScale:scale];
}
- (void)handlePan:(UIPanGestureRecognizer *)sender {
	static CGPoint p0 = [sender translationInView:self.view];
	CGPoint p = [sender translationInView:self.view];
	if(sender.state == UIGestureRecognizerStateBegan)
		p0 = p;
	
	CGPoint dP;
	dP.x = p.x - p0.x;
	dP.y = p.y - p0.y;
	p0 = p;
	NSLog(@"Translation: %f, %f", [sender translationInView:self.view].x, [sender translationInView:self.view].y);
	[self.glView translate:dP];
}

@end
