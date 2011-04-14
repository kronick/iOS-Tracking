//
//  Homography.h
//  trackingTest
//
//  Created by kronick on 2/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

typedef struct {
	cv::Mat homography;
	int inliers;
} HomographyEstimate;

@interface Homography : NSObject {
	BOOL useFerns;
	cv::Mat sourceImage;
	cv::Mat *destImage;
	std::vector<cv::KeyPoint> sourceKeyPoints;
	std::vector<cv::KeyPoint> *destKeyPoints;
	cv::Mat sourceDescriptors;
	cv::Mat destDescriptors;
	
	cv::Mat cameraMatrix;
	cv::Mat rotationVector;
	cv::Mat translationVector; 
	cv::Mat modelviewMatrix;
	
	CvMat rotationVec;
	CvMat translationVec;
	CvMat cameraMat;
	
	std::vector<int> keyPointMatches;
	cv::Mat matrix;
	
	BOOL sourceDescriptorsAreFresh;	// Reset after image is changed
	BOOL destDescriptorsAreFresh;
	BOOL trained; 
	cv::PlanarObjectDetector detector;	// Wraps Ferns-based matcher
	cv::FernClassifier fern;
	std::vector<int> pairs;
}

- (id)initWithSourceImage:(cv::Mat*)sourceMat sourceKeyPoints:(std::vector<cv::KeyPoint>*)sourcePoints destImage:(cv::Mat*)destMat destKeyPoints:(std::vector<cv::KeyPoint>*)destPoints;

- (NSArray *) getArray;
- (cv::Mat) getMatrix;
- (cv::Mat) getModelviewMatrix;

- (void) train;
- (BOOL) calculate;
- (cv::Mat) modelviewFromHomography:(cv::Mat) homoraphy;
- (void) loadTrainingData:(NSString *)resourceName;
- (void) saveTrainingData:(NSString *)resourceName;

- (void) setSourceKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer;
- (void) setDestKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer;
- (std::vector<cv::KeyPoint>) sourceKeyPoints;
- (std::vector<cv::KeyPoint> *) destKeyPoints;

- (cv::Mat) sourceImage;
- (cv::Mat *) destImage;
- (void) setSourceImage: (cv::Mat*) imageMat;
- (void) setDestImage: (cv::Mat*) imageMat;

- (BOOL) isTrained;

- (HomographyEstimate) findHomographyFrom:(cv::Mat&) fromPoints To:(cv::Mat&) toPoints;
@end
