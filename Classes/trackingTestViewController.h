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

@interface trackingTestViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
	AVCaptureSession *captureSession;
	AVCaptureVideoPreviewLayer *capturePreview;
	AVCaptureVideoDataOutput *captureVideoOutput;
	
	OverlayView *overlayView;
	
	cv::Mat mReferenceImage;
	cv::Mat mCapturedImage;
	std::vector<cv::KeyPoint>  mReferenceKeyPoints;
	std::vector<cv::KeyPoint> mDetectedKeyPoints;
	
	float FASTThreshold;
	int keyPointTarget;
	int frameCount;
	
	NSTimeInterval lastTime;
	
	cv::Mat mMilestoneImage;
	std::vector<cv::KeyPoint> mMilestoneKeyPoints;
	std::vector<std::vector<std::vector<cv::KeyPoint *> > > mKeyPointGrid;
	BOOL mMilestoneReady;
	BOOL setNewMilestone;
	
	PointTracker *pointTracker;
	
	Homography *objectFinder;
	
	vector<float> mReferenceDescriptor;
	
	cv::Ptr<cv::GenericDescriptorMatcher> mFernMatcher;
	
	int GRID_X;
	int GRID_Y;
}

@property (nonatomic,retain) PointTracker *pointTracker;
@property (nonatomic,retain) Homography *objectFinder;

- (void)redrawKeyPoints:(NSTimer *)timer;

- (IBAction)setReferenceImage;
- (IBAction)findReferenceImage;
- (IBAction)track;
- (void)updateMatch:(NSTimer*)theTimer;

- (void) setMilestone;


@property (nonatomic,retain) IBOutlet UIView *previewView;
@property (nonatomic,retain) IBOutlet OverlayView *overlayView;

@property (nonatomic,retain) AVCaptureSession *captureSession;
@property (nonatomic,retain) AVCaptureVideoPreviewLayer *capturePreview;
@property (nonatomic,retain) AVCaptureVideoDataOutput *captureVideoOutput;

@end

