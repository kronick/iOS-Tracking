//
//  Homography.m
//  trackingTest
//
//  Created by kronick on 2/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Homography.h"
#include <opencv2/objdetect/objdetect.hpp>
#include <opencv2/features2d/features2d.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <opencv2/imgproc/imgproc_c.h>
#include "CvModelEstimator.h"

using namespace cv;
using namespace std;
@implementation Homography

- (id)init {
    
    self = [super init];
    if (self) {
		useFerns = YES;
        // Initialization code.
		matrix = Mat(3,3, CV_64F);
		
		cameraMatrix = Mat(3,3, CV_64F);
		cameraMatrix.at<double>(0,0) = 786.42938232;	// f_x (Focal length)
		cameraMatrix.at<double>(1,1) = 786.42938232;	// f_y
		cameraMatrix.at<double>(2,2) = 1;
		cameraMatrix.at<double>(0,2) = 320; //311.25384521;	// c_x (Lens center)
		cameraMatrix.at<double>(1,2) = 240; //217.01358032;	// c_y 
		
		rotationVector.create(3,1,CV_32FC1);
		translationVector.create(3,1,CV_32FC1);
		
		double cameraValues[] = {786.42938232, 0, 311.25384521,
								 0, 786.42938232, 217.01358032,
								 0, 0, 1};
		cameraMat = cvMat(3,3, CV_64F, cameraValues);
		rotationVec = cvMat(3,1, CV_64F);
		translationVec = cvMat(3,1, CV_64F);
		trained = NO;
    }
    return self;
}


- (id)initWithSourceImage:(cv::Mat*)sourceMat sourceKeyPoints:(std::vector<cv::KeyPoint>*)sourcePoints destImage:(cv::Mat*)destMat destKeyPoints:(std::vector<cv::KeyPoint>*)destPoints {
	[self init];
	if(self) {
		sourceImage = *sourceMat;
		sourceKeyPoints = *sourcePoints;
		destImage = destMat;
		destKeyPoints = destPoints;
		sourceDescriptorsAreFresh = NO;
		destDescriptorsAreFresh = YES;
		trained = NO;
	}
	return self;
}



- (void)dealloc {
    [super dealloc];
}


#pragma mark -
#pragma mark Getters/Setters

- (cv::Mat) getMatrix {
	return matrix;
}
- (cv::Mat) getModelviewMatrix {
	return modelviewMatrix;
}

- (NSArray *) getArray {
	NSMutableArray *output = [NSMutableArray arrayWithCapacity:9];
	for(int i=0; i<3; i++) {
		for(int j=0; j<3; j++) {
			[output addObject:[NSNumber numberWithDouble:matrix.at<double>(i,j)]];
		}
	}
	
	return output;
}

- (std::vector<cv::KeyPoint>) sourceKeyPoints {
	return sourceKeyPoints;
}
- (std::vector<cv::KeyPoint> *) destKeyPoints {
	return destKeyPoints;
}

- (void) setSourceKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer {
	trained = NO;
	sourceKeyPoints = *keyPointPointer;
}
- (void) setDestKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer {
	destKeyPoints = keyPointPointer;
}

- (cv::Mat) sourceImage {
	return sourceImage;
}
- (cv::Mat *) destImage {
	return destImage;
}
- (void) setSourceImage: (cv::Mat*) imageMat {
	trained = NO;
	sourceImage = *imageMat;
	sourceDescriptorsAreFresh = NO;	
}
- (void) setDestImage: (cv::Mat*) imageMat {
	destImage = imageMat;
	destDescriptorsAreFresh = NO;
}

#pragma mark -
#pragma mark File handling

- (void) loadTrainingData:(NSString *)resourceName {
	NSLog(@"Trying to load \"%@\"", resourceName);
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	string filePath([[NSString stringWithFormat:@"%@/%@", documentsDirectory, resourceName] cString]);
	
    FileStorage fs(filePath, FileStorage::READ);
    if(fs.isOpened()) {
		FileNode node = fs.getFirstTopLevelNode();
        fern.read(node["fern-classifier"]);
		cv::read(node["model-points"], sourceKeyPoints);
        NSLog(@"Training data successfully loaded.");
		trained = YES;
    }
    else {
		NSLog(@"That file does not exist.");
	}
}

- (void) saveTrainingData:(NSString *)resourceName {
	NSLog(@"Trying to save to \"%@\"", resourceName);
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	string filePath([[NSString stringWithFormat:@"%@/%@", documentsDirectory, resourceName] cString]);
	
    FileStorage fs(filePath, FileStorage::WRITE);	
	if(fs.isOpened()) {
		WriteStructContext ws(fs, "ferns_model", CV_NODE_MAP);
		cv::write(fs, "model-points", sourceKeyPoints);
		fern.write(fs, "fern-classifier");
		NSLog(@"Training data written!");
	}
	else {
		NSLog(@"Training data file could not be opened.");
	}
}

#pragma mark -
#pragma mark Calculation

- (void) train {
	trained = NO;
	NSLog(@"Need to train to source image...");
	// backgroundMin, backgroundMax, noiseRange, randomBlur, scaleMin, scaleMax, z-rotation min, z-rotation max, tilt min, tilt max
	PatchGenerator patchGen(0,256,5,true,0.2,1.5,-CV_PI/4,CV_PI/4,-CV_PI/2,CV_PI/2);
	fern.setVerbose(true);
	//for(int i=0; i<sourceKeyPoints.size(); i++) 
	//	NSLog(@"%f , %f", sourceKeyPoints[i].pt.x, sourceKeyPoints[i].pt.y);
	//NSLog(@"Source keypoint size: %i", sourceKeyPoints[0].pt.y);
	fern.trainFromSingleView(sourceImage, sourceKeyPoints,
							 32, (int)sourceKeyPoints.size(), 20, 10, 500,
							 FernClassifier::COMPRESSION_NONE, patchGen);
	
	// Rescale keypoints
	for(vector<KeyPoint>::iterator it = sourceKeyPoints.begin(); it != sourceKeyPoints.end(); it++) {
		(*it).pt.x *= 640./sourceImage.cols*2;
		(*it).pt.y *= 640./sourceImage.cols*2;
	}
	
	NSLog(@"Training complete!");
	sourceDescriptorsAreFresh = YES;
	trained = YES;
}
- (BOOL) isTrained {
	return trained;
}

- (BOOL) calculate {
	if(useFerns) {	// Use Ferns
		// Based on find_obj_ferns.cpp in OpenCV samples directory
		// Edited to remove LDetector, as corner detection is done using FAST
		// ------------------------------------------------------------------
		if(!trained) {
		Homography:
			matrix = (Mat_<double>(3,3) << 0.258145, 0.031288 , 162.400510,
											-0.170125 , 0.703209 , 79.328281,
											-0.000528	, -0.000046 , 1.000000);
			
			modelviewMatrix = [self modelviewFromHomography:matrix];
			
			
			//NSLog(@"%f\t%f\t%f\t%f", modelviewMatrix.at<float>(0,0), modelviewMatrix.at<float>(0,1), modelviewMatrix.at<float>(0,2),  modelviewMatrix.at<float>(0,3));
			//NSLog(@"%f\t%f\t%f\t%f", modelviewMatrix.at<float>(1,0), modelviewMatrix.at<float>(1,1), modelviewMatrix.at<float>(1,2),  modelviewMatrix.at<float>(1,3));
			//NSLog(@"%f\t%f\t%f\t%f", modelviewMatrix.at<float>(2,0), modelviewMatrix.at<float>(2,1), modelviewMatrix.at<float>(2,2),  modelviewMatrix.at<float>(2,3));
			//NSLog(@"%f\t%f\t%f\t%f", modelviewMatrix.at<float>(3,0), modelviewMatrix.at<float>(3,1), modelviewMatrix.at<float>(3,2),  modelviewMatrix.at<float>(3,3));
			return YES;
		}
		else {
			// Below is modified from planardetect.cpp OpenCV sample
			int i, j;
			int m = fern.getClassCount();
			int n = (int)destKeyPoints->size();
			vector<int> bestMatches(m, -1);
			vector<float> maxLogProb(m, -FLT_MAX);
			vector<float> signature;
			vector<Point2f> fromPt, toPt;
			
			float firstBestIndex = -1, secondBestIndex = -1;
			float firstBestProb = -FLT_MAX, secondBestProb = -FLT_MAX;
			for( i = 0; i < n; i++ )
			{
				firstBestIndex = -1; secondBestIndex = -1;
				firstBestProb = -FLT_MAX; secondBestProb = -FLT_MAX;
				KeyPoint kpt = (*destKeyPoints)[i];
				int firstBestIndex = fern(*destImage, kpt.pt, signature);	// Returns the point index of the most likely match
																// Signature contains probabilities of a match with each source keypoint
				if( firstBestIndex >= 0 && (bestMatches[firstBestIndex] < 0 || signature[firstBestIndex] > maxLogProb[firstBestIndex]))	// If this is the new best match for a point, update the match index array
				{
					firstBestProb = signature[firstBestIndex];
					// Find second best match
					for(j=0; j<m; j++) {
						if(j != firstBestIndex && signature[j] > secondBestProb) {
							secondBestIndex = j;
							secondBestProb = signature[j];
						}
					}
					// Compare ratio of first and second best matches
					
					//if(firstBestProb-secondBestProb > 3) {
					//if(firstBestProb > -90 && firstBestProb-secondBestProb > 4) {
					if(firstBestProb-secondBestProb > 6) {
						//NSLog(@"Good point ratio: %f", firstBestProb-secondBestProb);
						//NSLog(@"Good point: %f", firstBestProb);
						
						//NSLog(@"New best match for point %i with probability %f (beats %f)", k, signature[k], maxLogProb[k]);
						maxLogProb[firstBestIndex] = signature[firstBestIndex];
						bestMatches[firstBestIndex] = i;
					}
					//else
						//NSLog(@"Bad point ratio: %f", firstBestProb-secondBestProb);
				}
			}
			
			pairs.resize(0);
			
			vector<Point3f> threeDPoints;
			
			float sumLogProb = 0;
			for( i = 0; i < m; i++ ) {
				if( bestMatches[i] >= 0 )
				{
					fromPt.push_back(sourceKeyPoints[i].pt);
					//threeDPoints.push_back(Point3f(sourceKeyPoints[i].pt.x, sourceKeyPoints[i].pt.y, 0));
					toPt.push_back((*destKeyPoints)[bestMatches[i]].pt);
					//NSLog(@"Log prob: %f", maxLogProb[i]);
					sumLogProb += maxLogProb[i];
				}
			}
			
			//NSLog(@"Found %i points with average log prob %f", (int)fromPt.size(), sumLogProb/(float)fromPt.size());
			if( fromPt.size() >= 25 ) {
				vector<uchar> mask;
			
				//matrix = findHomography(Mat(fromPt), Mat(toPt), mask, RANSAC, 2);
				Mat from = Mat(fromPt);
				Mat to = Mat(toPt);
				NSLog(@"Sending %i points to RANSAC", fromPt.size());
				
				HomographyEstimate estimate = [self findHomographyFrom:from To:to];
				matrix = estimate.homography;
				
				
				if(matrix.data == 0 || estimate.inliers < 10) {
					// Did not detect object
					return NO;
				}
				
				modelviewMatrix = [self modelviewFromHomography:matrix];
				
				return YES;
			}
			else {
				return NO;
			}
		}			
	}	
	return NO;
}


- (cv::Mat) modelviewFromHomography:(cv::Mat) homography {
	
	// Decompose the Homography into translation and rotation vectors
	// Based on: https://gist.github.com/740979/97f54a63eb5f61f8f2eb578d60eb44839556ff3f
		
	Mat inverseCameraMatrix = (Mat_<double>(3,3) << 1/cameraMatrix.at<double>(0,0) , 0 , -cameraMatrix.at<double>(0,2)/cameraMatrix.at<double>(0,0) ,
							   0 , 1/cameraMatrix.at<double>(1,1) , -cameraMatrix.at<double>(1,2)/cameraMatrix.at<double>(1,1) ,
							   0 , 0 , 1);
		
	Mat G = inverseCameraMatrix * matrix;
	Mat G1 = (Mat_<double>(3,1) << G.at<double>(0,0) , G.at<double>(1,0) , G.at<double>(2,0));
	Mat G2 = (Mat_<double>(3,1) << G.at<double>(0,1) , G.at<double>(1,1) , G.at<double>(2,1));
	Mat G3 = (Mat_<double>(3,1) << G.at<double>(0,2) , G.at<double>(1,2) , G.at<double>(2,2));
	
	Mat H1 = (Mat_<double>(3,1) << matrix.at<double>(0,0) , matrix.at<double>(1,0) , matrix.at<double>(2,0));
	
	double lambda = sqrt(cv::norm(G1) * cv::norm(G2));

	//NSLog(@"G3: %f\t%f\t%f", G.at<double>(2,0), G.at<double>(2,1), G.at<double>(2,2));
	
	Mat r1 = (Mat_<double>(3,1) << G1.at<double>(0,0) / lambda, G1.at<double>(1,0) / lambda, G1.at<double>(2,0) / lambda);	// Rotation axis 1
	Mat r2 = (Mat_<double>(3,1) << G2.at<double>(0,0) / lambda, G2.at<double>(1,0) / lambda, G2.at<double>(2,0) / lambda);	// Rotation axis 2
	Mat t = (Mat_<double>(3,1) << G3.at<double>(0,0) / lambda / 640, -G3.at<double>(1,0) / lambda / 640, -G3.at<double>(2,0) / lambda / 640);	// Translation vector
	
	// Make r1 and r2 orthogonal
	Mat c = r1 + r2;
	Mat p = r1.cross(r2);
	Mat d = c.cross(p);
	
	r1 = 1/sqrt(2) * (c / cv::norm(c) + d / cv::norm(d));
	r2 = 1/sqrt(2) * (c / cv::norm(c) - d / cv::norm(d));
	Mat r3 = r1.cross(r2);
	
	// Make a rotation matrix, convert to rotation vector, flip x-axis rotation, convert back to rotation matrix
	Mat R = (Mat_<double>(3,3) <<	r1.at<double>(0,0), r1.at<double>(1,0), r1.at<double>(2,0),
			 r2.at<double>(0,0), r2.at<double>(1,0), r2.at<double>(2,0),
			 r3.at<double>(0,0), r3.at<double>(1,0), r3.at<double>(2,0));
	R = R.t();
	Mat flip_x = (Mat_<double>(3,3) << 1,0,0 , 0,-1,0, 0,0,-1);
	R = flip_x * R * flip_x;
		
	return (Mat_<float>(4,4) <<	R.at<double>(0,0), R.at<double>(0,1), R.at<double>(0,2), t.at<double>(0,0),
								R.at<double>(1,0), R.at<double>(1,1), R.at<double>(1,2), t.at<double>(1,0),
								R.at<double>(2,0), R.at<double>(2,1), R.at<double>(2,2), t.at<double>(2,0),
								0, 0, 0, 1);
	
}

- (HomographyEstimate) findHomographyFrom:(cv::Mat&)fromPoints To:(cv::Mat&) toPoints {
	// Make sure we have valid matrices with enough (4) points
	CV_Assert(fromPoints.isContinuous() && toPoints.isContinuous() &&
              fromPoints.type() == toPoints.type() &&
              ((fromPoints.rows == 1 && fromPoints.channels() == 2) ||
               fromPoints.cols*fromPoints.channels() == 2) &&
              ((toPoints.rows == 1 && toPoints.channels() == 2) ||
               toPoints.cols*toPoints.channels() == 2));

	int count = MAX(fromPoints.cols, fromPoints.rows);
	//NSLog(@"Using %i points", count);
	
	// Convert cv::Mat to CvMat
	CvMat _pt1 = Mat(toPoints), _pt2 = Mat(fromPoints);
	
	// Convert points to homogeneous coordinates
	cv::Ptr<CvMat> fromPoints_homogeneous, toPoints_homogeneous;
	
	fromPoints_homogeneous = cvCreateMat(1, count, CV_64FC2);
	cvConvertPointsHomogeneous(&_pt1, fromPoints_homogeneous);	// m
	
	toPoints_homogeneous = cvCreateMat( 1, count, CV_64FC2);
	cvConvertPointsHomogeneous(&_pt2, toPoints_homogeneous);	// M
	
	// Set the input mask to all 1's
	cv::Ptr<CvMat> tempMask;
	tempMask = cvCreateMat( 1, count, CV_8U );
	cvSet( tempMask, cvScalarAll(1.) );
	
	// Set RANSAC parameters
	const double confidence = 0.999;			// 0.995
	const int maxIters = 500;					// OpenCV default is hardcoded to 2000
	const double ransacReprojThreshold = 1;		// 3
	bool result = false;
	
	Mat H(3, 3, CV_64F);    
    CvMat matH = H;			// matH points to H, our return value
	
	CvHomographyEstimator estimator(MIN(count, 4));
	result = estimator.runRANSAC(toPoints_homogeneous, fromPoints_homogeneous, &matH, tempMask, ransacReprojThreshold, confidence, maxIters);
	
	if(result && count > 4) {
		icvCompressPoints((CvPoint2D64f*)toPoints_homogeneous->data.ptr, tempMask->data.ptr, 1, count);
		count = icvCompressPoints((CvPoint2D64f*)fromPoints_homogeneous->data.ptr, tempMask->data.ptr, 1, count);
		toPoints_homogeneous->cols = fromPoints_homogeneous->cols = count;

		estimator.runKernel(toPoints_homogeneous, fromPoints_homogeneous, &matH);	// RANSAC only?
		estimator.refine(toPoints_homogeneous, fromPoints_homogeneous, &matH, 10);
	}
	
	NSLog(@"Inliers? %i", count);
	
	if(!result)
		H = Scalar(0);
	
	HomographyEstimate estimate;
	estimate.homography = H;
	estimate.inliers = count;
	return estimate;
}

template<typename T> int icvCompressPoints( T* ptr, const uchar* mask, int mstep, int count )
{
	/** Modifies the matrix pointed to by the first arg to only include indices included in the mask
	*/
    int i, j;
    for( i = j = 0; i < count; i++ )
        if( mask[i*mstep] )
        {
            if( i > j )
                ptr[j] = ptr[i];
            j++;
        }
    return j;
}

@end
