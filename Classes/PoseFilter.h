/*
 *  PoseFilter.h
 *  trackingTest
 *
 *  Created by kronick on 4/18/11.
 *  Copyright 2011 Sam Kronick
 *	
 *	Modified Kalman filter for combining vision- and inertial sensor-based pose estimates
 */

#include <opencv2/opencv.hpp>
#ifndef _POSE_FILTER_H_
#define _POSE_FILTER_H_

enum PoseEstimateType { CAMERA_POSE, GYRO_POSE, GPS_POSE };

class PoseFilter {
 public:
	PoseFilter();
	cv::Mat Predict(double timestamp);
	cv::Mat Correct(const cv::Mat& measurement_in, PoseEstimateType poseType, double timestamp);
	void setCameraTarget(const cv::Mat& target);
	void setGyrosCovariance(float cov);
	void setCameraCovariance(float cov);
private:	
	int cameraMeasurementCount;
	int gyrosMeasurementCount;
	int gpsMeasurementCount;
	int stateCount;
	
	cv::Mat statePre;					// x-
	cv::Mat statePost;					// x
	cv::Mat covariancePre;				// P-
	cv::Mat	covariancePost;				// P
	
	cv::Mat cameraCovariance;			// [R_1]
	cv::Mat gyrosCovariance;			// [R_2]
	cv::Mat gpsCovariance;				// [R_3]
	cv::Mat processCovariance;			// [Q]
	
	cv::Mat cameraObservationModel;		// [H_1]
	cv::Mat gyrosObservationModel;		// [H_2]
	cv::Mat gpsObservationModel;		// [H_3]
	
	cv::Mat stateTransitionModel;		// [A]
	float velocityDrag;
	
	double lastPredictionTime;			// Used for calculating dT
	double lastCameraMeasurementTime;	// Used for calculating velocity
	double lastGpsMeasurementTime;		// Used for calculating velocity
	
	cv::Mat lastCameraMeasurement;
	cv::Mat lastGpsMeasurement;
	cv::Mat cameraTarget;				// Used for smoothing
	cv::Mat cameraState;				// Used for smoothing
};

#endif