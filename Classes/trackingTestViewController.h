//
//  trackingTestViewController.h
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "Utilities.h"

#import "TrackedPoint.h"
#import "PointTracker.h"
#import "Homography.h"

#import "overlayView.h"
#import "GLView.h"
#import <CoreMotion/CoreMotion.h>
#import "ImageTaggerViewController.h"

#include "PoseFilter.h"


@interface trackingTestViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, ImageTaggerDelegate, UIGestureRecognizerDelegate> {
	AVCaptureSession *captureSession;
	AVCaptureVideoPreviewLayer *capturePreview;
	AVCaptureVideoDataOutput *captureVideoOutput;
	
	//OverlayView *overlayView;
	
	cv::Mat mReferenceImage;
	cv::Mat mCapturedImage;
	std::vector<cv::KeyPoint>  mReferenceKeyPoints;
	std::vector<cv::KeyPoint> mDetectedKeyPoints;
	
	float FASTThreshold;
	int keyPointTarget;
	int frameCount;
	
	NSTimeInterval lastTime;
	
	IBOutlet UILabel *framerateLabel;
	IBOutlet UILabel *foundPointsLabel;
	
	Homography *objectFinder;
	
	vector<float> mReferenceDescriptor;
	
	cv::Ptr<cv::GenericDescriptorMatcher> mFernMatcher;
	
	GLView *glView;
	IBOutlet UIView *statusView;
	
	// not used anymore
	int GRID_X;
	int GRID_Y;
	cv::Mat mMilestoneImage;
	std::vector<cv::KeyPoint> mMilestoneKeyPoints;
	std::vector<std::vector<std::vector<cv::KeyPoint *> > > mKeyPointGrid;
	BOOL mMilestoneReady;
	BOOL setNewMilestone;
	PointTracker *pointTracker;
	
	// Core motion sensors
	CMMotionManager *motionManager;
	
	// Kalman filter stuff
	PoseFilter poseFilter;
	
	BOOL poseInitialized;
	CMAttitude *referenceAttitude;
	cv::Mat referenceRotationMatrix;
	cv::Mat referenceRotationMatrixTarget;
	cv::Mat referenceAttitudeMatrix;
	cv::Mat referenceAttitudeMatrixTarget;
	
	cv::Mat visionEstimate;
	BOOL visionTargetFound;
	BOOL visionTrackingOn;
	IBOutlet UISwitch *visionTrackingSwitch;
	BOOL gyroTrackingOn;
	IBOutlet UISwitch *gyroTrackingSwitch;
	
	ImageTaggerViewController *imageTaggerView;
}

@property (nonatomic,retain) PointTracker *pointTracker;
@property (nonatomic,retain) Homography *objectFinder;
@property (nonatomic,retain) GLView *glView;
@property (nonatomic,retain) IBOutlet UIView *statusView;
@property (nonatomic,retain) CMMotionManager *motionManager;
@property (nonatomic,retain) CMAttitude *referenceAttitude;

@property (nonatomic,retain) IBOutlet UIView *previewView;
//@property (nonatomic,retain) IBOutlet OverlayView *overlayView;

@property (nonatomic,retain) AVCaptureSession *captureSession;
@property (nonatomic,retain) AVCaptureVideoPreviewLayer *capturePreview;
@property (nonatomic,retain) AVCaptureVideoDataOutput *captureVideoOutput;

@property (nonatomic,retain) IBOutlet UISwitch *visionTrackingSwitch;
@property (nonatomic,retain) IBOutlet UISwitch *gyroTrackingSwitch;

@property (nonatomic,retain) UILabel *framerateLabel;
@property (nonatomic,retain) UILabel *foundPointsLabel;

@property (nonatomic,retain) ImageTaggerViewController *imageTaggerView;

- (void)redrawKeyPoints:(NSTimer *)timer;

- (IBAction)setReferenceImage;
- (IBAction)loadReference;
- (IBAction)findReferenceImage;
- (IBAction)track;
- (IBAction)visionSwitchChanged;
- (IBAction)gyroSwitchChanged;
- (IBAction)launchImageTagger;

- (void)pauseCaptureSession;
- (void)resumeCaptureSession;

- (void)updateMatch:(NSTimer*)theTimer;

- (void)updateSensorPose:(NSTimer*)theTimer;

- (void) setMilestone;

- (void)handlePinch:(UIPinchGestureRecognizer *)sender;
- (void)handlePan:(UIPanGestureRecognizer *)sender;


@end

