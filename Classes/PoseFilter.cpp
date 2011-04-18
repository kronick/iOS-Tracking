/*
 *  PoseFilter.cpp
 *  trackingTest
 *
 *  Created by kronick on 4/18/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include "PoseFilter.h"

using namespace cv;

PoseFilter::PoseFilter() {
	// Set the various matrices to their defaults
	stateCount				= 15;		// X,Y,Z, dX,dY,dZ, 3x3 rotation matrix
	statePre				= Mat::zeros(stateCount,1, CV_32F);
	statePost				= (Mat_<float>(stateCount,1) << 0,0,2, 0,0,0, 0,1,0, 1,0,0, 0,0,1);	// Initial estimate
	covariancePre			= Mat::zeros(stateCount,stateCount, CV_32F);
	covariancePost			= Mat::zeros(stateCount,stateCount, CV_32F);
	
	cameraMeasurementCount	= 15;		// X,Y,Z, dX,dY,dZ, 3x3 rotation matrix
	gyrosMeasurementCount	= 9;		// 3x3 rotation matrix
	gpsMeasurementCount		= 6;		// X,Y,Z, dX,dY,dZ
	
	cameraCovariance		= Mat::eye(cameraMeasurementCount,cameraMeasurementCount, CV_32F) * 0.0001f;
	gyrosCovariance			= Mat::eye(gyrosMeasurementCount,gyrosMeasurementCount, CV_32F) * 0.00001f;
	gpsCovariance			= Mat::eye(gpsMeasurementCount,gpsMeasurementCount, CV_32F) * 0.001f;
	processCovariance		= Mat::eye(15,15, CV_32F) * 0.00001f;
	
	// Build observation models
	cameraObservationModel	= Mat::eye(cameraMeasurementCount,stateCount, CV_32F);
	
	gyrosObservationModel	= Mat::zeros(gyrosMeasurementCount,stateCount, CV_32F);
	gyrosObservationModel.at<float>(0,6) = 1;
	gyrosObservationModel.at<float>(1,7) = 1;
	gyrosObservationModel.at<float>(2,8) = 1;
	gyrosObservationModel.at<float>(3,9) = 1;
	gyrosObservationModel.at<float>(4,10) = 1;
	gyrosObservationModel.at<float>(5,11) = 1;
	gyrosObservationModel.at<float>(6,12) = 1;
	gyrosObservationModel.at<float>(7,13) = 1;
	gyrosObservationModel.at<float>(8,14) = 1;
	
	gpsObservationModel		= Mat::eye(gpsMeasurementCount,stateCount, CV_32F);
	
	// Set what we can on the state transition model... dT terms will need to be set in predict method
	velocityDrag = 0.5f;
	stateTransitionModel	= Mat::eye(stateCount,stateCount, CV_32F);
	stateTransitionModel.at<float>(3,3) = velocityDrag;
	stateTransitionModel.at<float>(4,4) = velocityDrag;
	stateTransitionModel.at<float>(5,5) = velocityDrag;
	
	lastPredictionTime = 0;
}

Mat PoseFilter::Predict(float timestamp) {
	// Set dT
	if(lastPredictionTime == 0) lastPredictionTime = timestamp;
	float dT = timestamp - lastPredictionTime;
	lastPredictionTime = timestamp;
	stateTransitionModel.at<float>(0,3) = dT;
	stateTransitionModel.at<float>(1,4) = dT;
	stateTransitionModel.at<float>(2,5) = dT;
	
	statePre = stateTransitionModel * statePost;	// x- = [A][x]
	covariancePre = stateTransitionModel * covariancePost * stateTransitionModel.t() + processCovariance;	// [A][P_k-1][A^T] + [Q]
	
	return statePre;
}

Mat PoseFilter::Correct(Mat measurement, PoseEstimateType poseType) {
	Mat measurementObservationModel, measurementCovariance;
	switch(poseType) {
		case CAMERA_POSE:
			assert(measurement.rows == cameraMeasurementCount);
			measurementObservationModel		= cameraObservationModel;
			measurementCovariance			= cameraCovariance;
			break;
		case GYRO_POSE:
			assert(measurement.rows == gyrosMeasurementCount);
			measurementObservationModel		= gyrosObservationModel;
			measurementCovariance			= gyrosCovariance;
			break;
		case GPS_POSE:
			assert(measurement.rows == gpsMeasurementCount);
			measurementObservationModel		= gpsObservationModel;
			measurementCovariance			= gpsCovariance;
			break;
	}
	
	Mat S = measurementObservationModel * covariancePre * measurementObservationModel.t() + measurementCovariance;
	Mat KalmanGain = covariancePre * measurementObservationModel.t() * S.inv();
	statePost = statePre + KalmanGain * (measurement - measurementObservationModel * statePre);
	covariancePost = (Mat::eye(stateCount,stateCount, CV_32F) - (KalmanGain * measurementObservationModel)) * covariancePre;
	
	return statePost;
}
