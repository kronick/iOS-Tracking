//
//  ImageTaggerViewController.h
//  trackingTest
//
//  Created by kronick on 4/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <opencv/cv.h>
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "UIImage+cvConversions.h"

@interface ImageTaggerViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate, CLLocationManagerDelegate> {
	IBOutlet UIView *setCornersView;
	IBOutlet UIView *setMaskView;
	IBOutlet UIView *setLocationView;
	IBOutlet UIView *setElevationView;
	
	UIView *maximizedView;
	CGRect maximizedOriginalFrame;
	
	IBOutlet UIImageView *originalFacadeView;
	IBOutlet UIImageView *rectifiedFacadeView;
	IBOutlet UIImageView *elevationBackgroundView;
	IBOutlet MKMapView *mapView;

	IBOutlet UIImageView *originalFacadePhoto;	// As passed in from the UIImagePickerController
	IBOutlet UIImageView *rectifiedFacadePhoto;	// Corrected for perspective
	IBOutlet UIImage *facadeThumbnail;		// Cropped to the four corners
	
	UIToolbar *toolbar;
	
	UIImagePickerController *imagePicker;
	
	CLLocationManager *locationManager;
	BOOL foundCurrentLocation;
	
	BOOL cornersDragging[4];
	IBOutlet UIImageView *corner0;
	IBOutlet UIImageView *corner1;
	IBOutlet UIImageView *corner2;
	IBOutlet UIImageView *corner3;
}

@property (nonatomic,retain) UIView *maximizedView;
@property (nonatomic,retain) CLLocationManager *locationManager;
@property (nonatomic,retain) UIImagePickerController *imagePicker;

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation;
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error;

- (IBAction) closeImageTagger;
- (IBAction) showCamera;

- (void)tapReceived:(UITapGestureRecognizer *)sender;

- (void)moveCornerMarker:(UIImageView *)corner to:(CGPoint)point;
- (void)moveCornerMarker:(UIImageView *)corner by:(CGPoint)point;

- (void)updateRectifiedView;
@end
