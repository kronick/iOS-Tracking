//
//  Homography.h
//  trackingTest
//
//  Created by kronick on 2/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


@interface Homography : NSObject {
	cv::Mat sourceImage;
	cv::Mat *destImage;
	std::vector<cv::KeyPoint> sourceKeyPoints;
	std::vector<cv::KeyPoint> *destKeyPoints;
	cv::Mat sourceDescriptors;
	cv::Mat destDescriptors;
	
	std::vector<int> keyPointMatches;
	cv::Mat matrix;
	
	BOOL sourceDescriptorsAreFresh;	// Reset after image is changed
	BOOL destDescriptorsAreFresh;
}

- (id)initWithSourceImage:(cv::Mat*)sourceMat sourceKeyPoints:(std::vector<cv::KeyPoint>*)sourcePoints destImage:(cv::Mat*)destMat destKeyPoints:(std::vector<cv::KeyPoint>*)destPoints;

- (NSArray *) getArray;
- (cv::Mat) getMatrix;

- (void) calculate;
- (void) setSourceKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer;
- (void) setDestKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer;
- (std::vector<cv::KeyPoint>) sourceKeyPoints;
- (std::vector<cv::KeyPoint> *) destKeyPoints;

- (cv::Mat) sourceImage;
- (cv::Mat *) destImage;
- (void) setSourceImage: (cv::Mat*) imageMat;
- (void) setDestImage: (cv::Mat*) imageMat;

@end
