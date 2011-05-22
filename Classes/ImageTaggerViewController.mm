    //
//  ImageTaggerViewController.mm
//  trackingTest
//
//  Created by kronick on 4/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ImageTaggerViewController.h"


@implementation ImageTaggerViewController
@synthesize delegate;
@synthesize locationManager;
@synthesize imagePicker;
@synthesize maximizedView;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

	// Find location
	if(self.locationManager == nil) {
		self.locationManager = [[[CLLocationManager alloc] init] autorelease];
		self.locationManager.delegate = self;
		[self.locationManager startUpdatingLocation];
	}
	foundCurrentLocation = NO;
	
	// Set up camera picker and overlay contorller
	if(self.imagePicker == nil) {
		NSLog(@"Setting up image picker...");
		self.imagePicker = [[[UIImagePickerController alloc] init] autorelease];
		self.imagePicker.delegate = self;
		self.imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
		self.imagePicker.allowsEditing = NO;
		self.imagePicker.showsCameraControls = YES;
	}
	
	// Set up gestures	
	UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapReceived:)] autorelease];
	tapGestureRecognizer.delegate = self;
	tapGestureRecognizer.numberOfTapsRequired = 2;
	[setCornersView addGestureRecognizer:tapGestureRecognizer];
	UITapGestureRecognizer *tapGestureRecognizer2 = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapReceived:)] autorelease];
	tapGestureRecognizer2.delegate = self;
	tapGestureRecognizer2.numberOfTapsRequired = 2;
	[setMaskView addGestureRecognizer:tapGestureRecognizer2];
	UITapGestureRecognizer *tapGestureRecognizer3 = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapReceived:)] autorelease];
	tapGestureRecognizer3.delegate = self;
	tapGestureRecognizer3.numberOfTapsRequired = 2;
	[mapView addGestureRecognizer:tapGestureRecognizer3];
	
	
	for(int i=0; i<4; i++) {
		cornersDragging[i] = NO;
	}
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

#pragma mark -
#pragma mark Image Processing
- (void) updateRectifiedView {
	if(originalFacadeView.image != nil) {
		CGPoint c0,c1,c2,c3;
		c0 = CGPointMake(corner0.center.x/setCornersView.frame.size.width, corner0.center.y/setCornersView.frame.size.height);
		c1 = CGPointMake(corner1.center.x/setCornersView.frame.size.width, corner1.center.y/setCornersView.frame.size.height);
		c2 = CGPointMake(corner2.center.x/setCornersView.frame.size.width, corner2.center.y/setCornersView.frame.size.height);
		c3 = CGPointMake(corner3.center.x/setCornersView.frame.size.width, corner3.center.y/setCornersView.frame.size.height);
		
		IplImage *originalImg = [originalFacadeView.image IplImageRepresentation];
		CvSize imageSize = cvGetSize(originalImg);
		cv::Mat userCornersMat =		(cv::Mat_<double>(4,2) <<	imageSize.width * (double)c0.x,imageSize.height * (double)c0.y,
																	imageSize.width * (double)c1.x,imageSize.height * (double)c1.y,
																	imageSize.width * (double)c2.x,imageSize.height * (double)c2.y,
																	imageSize.width * (double)c3.x,imageSize.height * (double)c3.y);
		
		// Get aspect ratio
		// Using equations from: http://research.microsoft.com/en-us/um/people/zhang/Papers/WhiteboardRectification.pdf
		cv::Mat A = (cv::Mat_<float>(3,3) <<	786.42938232, 0, imageSize.width/2,
												0, 786.42938232, imageSize.height/2,
												0,0,1);
		
		float k2, k3;
		float ratio;
		cv::Mat _ratio;
		cv::Mat n2, n3;
		cv::Mat m1 = (cv::Mat_<float>(3,1) << imageSize.width * (float)c0.x, imageSize.height * (float)c0.y, 1);
		cv::Mat m2 = (cv::Mat_<float>(3,1) << imageSize.width * (float)c3.x, imageSize.height * (float)c3.y, 1);
		cv::Mat m3 = (cv::Mat_<float>(3,1) << imageSize.width * (float)c1.x, imageSize.height * (float)c1.y, 1);
		cv::Mat m4 = (cv::Mat_<float>(3,1) << imageSize.width * (float)c2.x, imageSize.height * (float)c2.y, 1);
		
		k2 = (m1.cross(m4).dot(m3)) / ((m2.cross(m4)).dot(m3));
		k3 = (m1.cross(m4).dot(m2)) / ((m3.cross(m4)).dot(m2));
		n2 = (k2*m2) - m1;
		n3 = (k3*m3) - m1;
		
		_ratio = (n2.t()*(A.inv().t())*(A.inv())*n2) / (n3.t()*(A.inv().t())*(A.inv())*n3);
		ratio = sqrt(_ratio.at<float>(0,0));
		
		NSLog(@"Ratio: %f", ratio);
		
		float imageRatio = imageSize.width/imageSize.height;
		float w = ratio > imageRatio ? imageSize.width : imageSize.height * ratio;
		float h = ratio > imageRatio ? imageSize.width / ratio : imageSize.height; 
		
		cv::Mat rectangleCornersMat =	(cv::Mat_<double>(4,2) << 0,0, 0,h, w,h, w,0);
		
		CvMat rectangleCorners =	rectangleCornersMat;
		CvMat userCorners =			userCornersMat;
		CvMat *homography =			cvCreateMat(3, 3, CV_64F);
		
		cvFindHomography(&userCorners, &rectangleCorners, homography, 0);
		cv::Mat homographyMat(homography);
		
		IplImage *rectifiedImg = cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 3);
		cvWarpPerspective(originalImg, rectifiedImg, homography, 0);
		
		cvCvtColor(rectifiedImg, rectifiedImg, CV_BGR2RGB);
		rectifiedFacadeView.image = [UIImage imageWithIplImage:rectifiedImg];
		
		/*
		cv::Mat resizedImage;
		cv::Mat grayImage;
		cv::resize(*rectifiedImg, resizedImage, cv::Size(640,480),0,0, INTER_LINEAR);
		cv::cvtColor(resizedImage, grayImage, CV_RGB2GRAY);
		
		cv::FAST(grayImage, mDetectedKeyPoints, FASTThreshold, true);
		// Dynamically adjust threshold 
		int n=0;
		while(fabs(mDetectedKeyPoints.size() - keyPointTarget) > keyPointTarget  * .1 && n++ < 500) {
			FASTThreshold += (float)(mDetectedKeyPoints.size() - (float)keyPointTarget) * .01;
			if(FASTThreshold > 200) FASTThreshold = 200;
			if(FASTThreshold < 1)   FASTThreshold = 1;
			cv::FAST(grayImage, mDetectedKeyPoints, FASTThreshold, true);
		}
		*/
		
		cvReleaseImage(&originalImg);
		cvReleaseImage(&rectifiedImg);
	}
}

#pragma mark -
#pragma mark IBActions
- (IBAction) closeImageTagger {
	originalFacadeView.image = nil;
	IplImage *trainImage = [rectifiedFacadeView.image IplImageRepresentation];
	cv::Mat trainingMat(trainImage);
	[self.delegate setTrainingImage:&trainingMat];
	cvReleaseImage(&trainImage);
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction) showCamera {
	originalFacadeView.image = nil;
	rectifiedFacadeView.image = nil;
	[self presentModalViewController:self.imagePicker animated:NO];
}


- (void)moveCornerMarker:(UIImageView *)corner to:(CGPoint)point {
	CGFloat _x, _y;
	switch(self.interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			point.x = [[UIScreen mainScreen] bounds].size.width - point.x;
			point.y = [[UIScreen mainScreen] bounds].size.height - point.y;
			break;
		case UIInterfaceOrientationLandscapeRight:
			_x = point.x;
			_y = point.y;
			point.x = _y;
			point.y = [[UIScreen mainScreen] bounds].size.width - _x;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			_x = point.x;
			_y = point.y;
			point.y = _x;
			point.x = [[UIScreen mainScreen] bounds].size.height - _y;
			break;
	}
	CGFloat x,y,w,h;
	x = corner.frame.origin.x;
	y = corner.frame.origin.y;
	w = corner.frame.size.width;
	h = corner.frame.size.height;
	
	corner.frame = CGRectMake(point.x - w/2., point.y - h/2., w, h);
	
	// TODO: Update the data structures that depend on the corners' positions
}

- (void)moveCornerMarker:(UIImageView *)corner by:(CGPoint)point {
	CGFloat x,y,w,h;
	x = corner.frame.origin.x;
	y = corner.frame.origin.y;
	w = corner.frame.size.width;
	h = corner.frame.size.height;
	
	corner.frame = CGRectMake(point.x + x, point.y + y, w, h);
	
	// TODO: Update the data structures that depend on the corners' positions
}

#pragma mark -

#pragma mark Touch Event Handlers
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	NSEnumerator *enumerator = [touches objectEnumerator];
	UITouch *touch = nil;
	while (touch = [enumerator nextObject]) {
		// Check to see if each touch is within one of the corner markers
		if(touch.view == corner0 || touch.view == corner1 || touch.view == corner2 || touch.view == corner3) {
			if(touch.view == corner0) 
					cornersDragging[0] = YES;
			if(touch.view == corner1)
					cornersDragging[1] = YES;
			if(touch.view == corner2)
					cornersDragging[2] = YES;
			if(touch.view == corner3)
					cornersDragging[3] = YES;
		}
	}
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	NSEnumerator *enumerator = [touches objectEnumerator];
	UITouch *touch = nil;
	while (touch = [enumerator nextObject]) {
		// Check to see if each touch is within one of the corner markers
		if(touch.view == corner0 || touch.view == corner1 || touch.view == corner2 || touch.view == corner3) {
			if(touch.view == corner0) 
				cornersDragging[0] = NO;
			if(touch.view == corner1)
				cornersDragging[1] = NO;
			if(touch.view == corner2)
				cornersDragging[2] = NO;
			if(touch.view == corner3)
				cornersDragging[3] = NO;
			
			if(maximizedView != setCornersView)	// Only update if the other view is visible
				[self updateRectifiedView];
		}
	}
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	NSEnumerator *enumerator = [touches objectEnumerator];
	UITouch *touch = nil;
	while (touch = [enumerator nextObject]) {
		if(touch.view == corner0 || touch.view == corner1 || touch.view == corner2 || touch.view == corner3) {
			CGPoint change;
			change.x = [touch locationInView:touch.view].x - [touch previousLocationInView:touch.view].x;
			change.y = [touch locationInView:touch.view].y - [touch previousLocationInView:touch.view].y;
			[self moveCornerMarker:(UIImageView *)touch.view by:change];
		}		
	}
}

#pragma mark UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	return (![touch.view isKindOfClass:[UIButton class]] && ![touch.view.superview isKindOfClass:[UIToolbar class]] && ![touch.view isKindOfClass:[UIToolbar class]]);
}
- (void)tapReceived:(UITapGestureRecognizer *)sender {
	UIView *maximizeView;
	if(![sender.view isMemberOfClass:[UIView class]])
		maximizeView = sender.view.superview;
	else
		maximizeView = sender.view;
		
	if(self.maximizedView != maximizeView) {
		NSLog(@"Maximizing...");
		self.maximizedView = maximizeView;
		maximizedOriginalFrame = maximizeView.frame;
		
		[self.view bringSubviewToFront:maximizeView];
		[UIView animateWithDuration:0.5 animations:^{
			maximizeView.frame = maximizeView.superview.bounds;
		} completion: ^(BOOL b){
		}];	
	}
	else {
		NSLog(@"Minimizing...");
		[UIView animateWithDuration:0.5 animations:^{
			maximizeView.frame = maximizedOriginalFrame;
		} completion: ^(BOOL b){
			if(maximizeView == setCornersView)
				[self updateRectifiedView];
			self.maximizedView = nil;
		}];			
	}
}



#pragma mark CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
	//NSLog(@"New location data: %f", [newLocation altitude]);

	if(!foundCurrentLocation) {
		MKCoordinateSpan span;
		MKCoordinateRegion region;
		span.longitudeDelta = 0.00001;
		span.latitudeDelta = 0.0001;
		region.span = span;
		region.center = newLocation.coordinate;
		[mapView setRegion:region animated:YES];
		foundCurrentLocation = YES;
	}
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"Error getting location: %@", error);
}

#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	UIImage *pickedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
	[self dismissModalViewControllerAnimated:YES];
	
	originalFacadeView.image = pickedImage;
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self dismissModalViewControllerAnimated:YES];
}


@end
