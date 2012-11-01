/*
 *  OverlayRenderer.cpp
 *  trackingTest
 *
 *  Created by kronick on 4/5/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include "OverlayRenderer.hpp"

OverlayRenderer::OverlayRenderer() {
	glGenRenderbuffersOES(1, &m_renderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_renderbuffer);
	frameCount = 0;
	moveCount = 0;
	scale = 1;
}

void OverlayRenderer::Initialize(int width, int height) {
	glGenFramebuffersOES(1, &m_framebuffer);
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_framebuffer);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, m_renderbuffer);
	
	glViewport(0, 0, width, height);
	
	m_modelviewMatrix[0] = 1;	m_modelviewMatrix[4] = 0;	m_modelviewMatrix[8] = 0;	m_modelviewMatrix[12] = 0;
	m_modelviewMatrix[1] = 0;	m_modelviewMatrix[5] = 1;	m_modelviewMatrix[9] = 0;	m_modelviewMatrix[13] = 0;
	m_modelviewMatrix[2] = 0;	m_modelviewMatrix[6] = 0;	m_modelviewMatrix[10] = 1;	m_modelviewMatrix[14] = 0;
	m_modelviewMatrix[3] = 0;	m_modelviewMatrix[7] = 0;	m_modelviewMatrix[11] = 0;	m_modelviewMatrix[15] = 1;
	
	m_drawOverlay = false;
	m_overlayFade = OVERLAY_FADE_TIME;

	memcpy(m_modelviewMatrix_target, m_modelviewMatrix, sizeof(GLfloat) * 16);
	
	glGenTextures(16, &m_textures[0]);
	
	glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    //glBlendFunc(GL_ONE, GL_SRC_COLOR);
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_DEPTH_TEST);
}

void OverlayRenderer::Render()  {
	frameCount++;
	
	// Draw 2D stuff
	// -------------
	glMatrixMode(GL_PROJECTION);
	
	const float maxX = 480;
	const float maxY = 640;
	glLoadIdentity();
	glOrthof(maxX, 0, maxY, 0, -1, 1);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glClearColor(0,0,0, 0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glPushMatrix();
	
	/*
	glColor4f(0, 1, 0, 1);
	for(int i=0; i<m_keypoints.size(); i++) {
		DrawRect(m_keypoints[i].pt.y, m_keypoints[i].pt.x, 2,2);
	}
	*/
	
	if(m_drawOverlay && false) {
		glColor4f(1, 1, 1, 1);
		for(int i=0; i<4; i++) {
			DrawLine(foundCorners[0].y, foundCorners[0].x, foundCorners[1].y, foundCorners[1].x);
			DrawLine(foundCorners[1].y, foundCorners[1].x, foundCorners[2].y, foundCorners[2].x);
			DrawLine(foundCorners[2].y, foundCorners[2].x, foundCorners[3].y, foundCorners[3].x);
			DrawLine(foundCorners[3].y, foundCorners[3].x, foundCorners[0].y, foundCorners[0].x);

			DrawLine(foundCorners[3].y, foundCorners[3].x, foundCorners[1].y, foundCorners[1].x);
			DrawLine(foundCorners[2].y, foundCorners[2].x, foundCorners[0].y, foundCorners[0].x);
		}
	}
	
	glPopMatrix();
	
	
	// Draw 3D stuff
	// -------------
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	double f_x = 786.42938232;	// Focal length in x axis
	double f_y = 786.42938232;	// Focal length in y axis (usually the same?)
	double c_x = 240;	//217.01358032;	// Camera primary point x
	double c_y = 320; //311.25384521;	// Camera primary point y
	
	double screen_width = 480;
	double screen_height = 640;

	double near = .1;
	double far = 1000;

	float cameraMatrix[] = {2*f_x/screen_width, 0, 0, 0,
							0, 2*f_y/screen_height, 0, 0,
							2*(c_x/screen_width) - 1, 2*(c_y/screen_height) - 1, (far + near)/(near-far), -1,
							0, 0, 2 * near * far / (near - far), 0};

	glMultMatrixf(cameraMatrix);
	
	// Ease into view
	double dist;
	for(int i=0; i<16; i++)	{	// Rotation
		dist = m_modelviewMatrix_target[i] - m_modelviewMatrix[i];
		m_modelviewMatrix[i] += 1 * dist * dist * (dist > 0 ? 1 : -1);
		m_modelviewMatrix[i] = m_modelviewMatrix_target[i];
	}

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glRotatef(-90, 0, 0, 1);
	glMultMatrixf(m_modelviewMatrix);
	//glRotatef(-90, 0, 0, 1);
	
	glTranslatef(0, -1, 0);
	
	if(!m_drawOverlay) {
		m_overlayFade--;
	}
	else {
		if(m_overlayFade < 0) m_overlayFade = 0;
		m_overlayFade++;
		if(m_overlayFade > OVERLAY_FADE_TIME) m_overlayFade = OVERLAY_FADE_TIME;
	}
	
	if(true ||  m_overlayFade > 0) {
		//glLoadIdentity();
		//glRotatef(-90, 0, 0, 1);
		//glTranslatef(0, 0, -2);
		//glRotatef(-45, 0, 1, 0);
		
		//float alpha = m_overlayFade/(float)OVERLAY_FADE_TIME;
		float alpha = 1;
		//float alpha = m_overlayFade%3 == 0 ? 1 : 0;	// Flicker
		
		//glTranslatef(0, 0, -2);
		
		/*
		//Draw grid lines----------------------------------------
		glColor4f(0.5*alpha, 0.5*alpha, 0.5*alpha, alpha*0.5);
		DrawRect(.125*2, .125*3, .25*2, .25*3);
		for(int i=-50; i<=50; i++) {
			DrawLine(.05*i,2.5,0, .05*i,-2.5,0);
			DrawLine(-2.5,.05*i,0, 2.5,.05*i,0);
			
			DrawLine(-2.5,.05*i,0, -2.5,.05*i,5);
			DrawLine(.05*i,-2.5,0, .05*i,-2.5,5);			
			DrawLine(2.5,.05*i,0, 2.5,.05*i,5);
			DrawLine(.05*i,2.5,0, .05*i,2.5,5);
			
			DrawLine(-2.5,-2.5,.05*(i+50), -2.5,2.5,.05*(i+50));
			DrawLine(-2.5,-2.5,.05*(i+50), 2.5,-2.5,.05*(i+50));
			DrawLine(2.5,2.5,.05*(i+50), -2.5,2.5,.05*(i+50));
			DrawLine(2.5,2.5,.05*(i+50), 2.5,-2.5,.05*(i+50));
			//DrawLine(.05*i,-2.5,0, .05*i,-2.5,5);			
			//DrawLine(2.5,.05*i,0, 2.5,.05*i,5);
			//DrawLine(.05*i,2.5,0, .05*i,2.5,5);
		}
		//DrawRect(0,0, 1,640./480.);
	
		
		// Draw axes
		glColor4f(1*alpha, 0, 0, alpha);
		DrawLine(0,0,0, 1,0,0);
		DrawLine(.5,0,0, .5,.05,0);
		DrawLine(.25,0,0, .25,.05,0);
		DrawLine(.75,0,0, .75,.05,0);
		
		glColor4f(0, 1*alpha, 0, alpha);
		DrawLine(0,0,0, 0,1,0);
		
		glColor4f(0, 0, 1*alpha, alpha);
		DrawLine(0,0,0, 0,0,1);
		*/
		
		// Draw some undulating stuff
		/*
		if(m_drawOverlay)
			moveCount++;
		float e = 0.1;
		float x,y,z;
		for(int i=0; i<16; i++) {
			for(int j=0; j<8; j++) {
				x = (8-i)*2*e;
				y = j*2*e;
				if(i%2==0) y+= 0.5 * 2*e;
				//y = j * e * 1.5;
				//x = (powf((j-8-(i/2)),2)+5*i)*e/4-1;
				z = sin((frameCount + 8*i)/13.)*.05 + sin((frameCount + 8*j)/20.)*.05 + .1; 
				glPushMatrix();
					glTranslatef(x, y, z);
					
					DrawSprite(1, 0, 0, e, e);
					glColor4f(1, 1, 1, .5);
					
					DrawLine(0,0,0, 0,0,-z);
					glColor4f(0,1,.5,.5);
					DrawPolygon(0,0, e/2, 6);
					glColor4f(1,1,1,1);
					glLineWidth(4);
					DrawPolygonStroke(0,0, e/2, 6);

				glPopMatrix();
			}
		}
		*/
		glTranslatef(translation.x, translation.y, 0);
		glScalef(scale, scale, scale);
		
		// Draw barn
		glColor4f(1, 1, 1, .3);
		DrawSprite(2, 1,0.5, 2,1);
		
		glColor4f(1, 1, 1, .75);
		// Draw rainbow
		glPushMatrix();
		//glTranslatef(0, 0, -10);
		DrawSprite(3, 0,2, 8,4, 0.0,0.584, 1.0,0.461);
		glPopMatrix();
		
		// Draw birds
		for(int i=0; i<10; i++) {
			glPushMatrix();
			glRotatef(frameCount/(2.+(cosf(i)+1))+20*i, 0,0,1);
			glTranslatef(3.5 + cosf(i), 0, cosf(frameCount/2)*0.05+0.2);
			glRotatef(-frameCount/(2.+(cosf(i)+1))-20*i, 0,0,1);
			DrawSprite(3, 0,0, 1,0.570, 0,0.4316, 1.0,0.289);
			glPopMatrix();
		}
		
		glColor4f(1, 1, 1, 1);
		
		// Draw cow
		glPushMatrix();
		glTranslatef(0, 0, .5);
		DrawSprite(3, -0.2,0.109, 0.33333,0.21866, 0.0,1, 1.0,0.836);
		glPopMatrix();
		
		glPushMatrix();
		glTranslatef(0.5, 0, .25);
		glRotatef(20, 0, 1, 0);
		DrawSprite(3, 0,0.109, 0.33333,0.21866, 0.0,1, 1.0,0.836);
		glPopMatrix();
		
		glPushMatrix();
		glTranslatef(1, 0, .1);
		glRotatef(-10, 0, 1, 0);
		DrawSprite(3, 0,0.109, 0.33333,0.21866, 0.0,1, 1.0,0.836);
		glPopMatrix();
		
		glPushMatrix();
		glTranslatef(2, 0, .6);
		glRotatef(-70, 0, 1, 0);
		DrawSprite(3, 0,0.109, 0.33333,0.21866, 0.0,1, 1.0,0.836);
		glPopMatrix();
	}
}

#pragma mark -
#pragma mark Setters/getters
void OverlayRenderer::setKeypoints(std::vector<cv::KeyPoint> newKeypoints) {
	m_keypoints = newKeypoints;
}
void OverlayRenderer::setCorners(CGPoint corners[]) {
	for(int i=0; i<4; i++)
		foundCorners[i] = corners[i];
}
void OverlayRenderer::setModelviewMatrix(cv::Mat matrix) {
	if(matrix.data != 0)
		for(int i=0; i<16; i++)
			m_modelviewMatrix_target[i] = matrix.at<float>(i%4, (int)i/4);
}

void OverlayRenderer::setDrawOverlay(bool draw) {
	m_drawOverlay = draw;
}

#pragma mark -
#pragma mark Drawing functions

void OverlayRenderer::DrawRect(float x, float y, float width, float height) {
	float h_width  = width  * 0.5f;
	float h_height = height * 0.5f;
	vertex2 Vertices[] = {
		{x-h_width, y-h_height},
		{x+h_width, y-h_height},
		{x+h_width, y+h_height},
		{x-h_width, y-h_height},
		{x+h_width, y+h_height},
		{x-h_width, y+h_height}
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glDrawArrays(GL_TRIANGLES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}

void OverlayRenderer::DrawSprite(GLuint textureID, float x, float y, float width, float height) {
	DrawSprite(textureID, x, y, width, height, 0,1, 1,0);
}
void OverlayRenderer::DrawSprite(GLuint textureID, float x, float y, float width, float height,
								float ULs, float ULt, float BRs, float BRt) {
	float h_width  = width  * 0.5f;
	float h_height = height * 0.5f;
	vertex2 Vertices[] = {
		{x-h_width, y+h_height},
		{x+h_width, y+h_height},
		{x-h_width, y-h_height},
		{x+h_width, y-h_height}
	};
	
	vertex3 Normals[] = {
		{0.0,0.0,1.0},
		{0.0,0.0,1.0},
		{0.0,0.0,1.0},
		{0.0,0.0,1.0}
	};
	
	GLfloat TextureCoords[] = {
		ULs, ULt,
		BRs, ULt,
		ULs, BRt,
		BRs, BRt
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindTexture(GL_TEXTURE_2D, textureID+1);
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	glNormalPointer(GL_FLOAT, sizeof(vertex3), &Normals[0].x);
	glTexCoordPointer(2, GL_FLOAT, sizeof(GLfloat)*2, TextureCoords);
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}

void OverlayRenderer::DrawCircleStroke(float x, float y, float radius) {
	DrawPolygonStroke(x,y,radius,20);
}
void OverlayRenderer::DrawCircle(float x, float y, float radius) {
	DrawPolygon(x,y,radius,20);
}
void OverlayRenderer::DrawPolygon(float x, float y, float radius, int sides) {
	vertex2 Vertices[sides+2];
	Vertices[0].x = x;
	Vertices[0].y = y;
	for(int i=1; i<sides+2; i++) {
		Vertices[i].x = radius * cosf((float)i/sides * M_PI * 2);
		Vertices[i].y = radius * sinf((float)i/sides * M_PI * 2);
	}
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glDrawArrays(GL_TRIANGLE_FAN, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}
void OverlayRenderer::DrawPolygonStroke(float x, float y, float radius, int sides) {
	vertex2 Vertices[sides];
	for(int i=0; i<sides; i++) {
		Vertices[i].x = radius * cosf((float)i/sides * M_PI * 2);
		Vertices[i].y = radius * sinf((float)i/sides * M_PI * 2);
	}
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glDrawArrays(GL_LINE_LOOP, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}



void OverlayRenderer::DrawLine(float x1, float y1, float z1, float x2, float y2, float z2) {
	vertex3 vertices[] = {
		{x1,y1,z1},
		{x2,y2,z2}
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(3, GL_FLOAT, sizeof(vertex3), &vertices[0].x);
	
	GLsizei vertexCount = sizeof(vertices) / sizeof(vertex3);
	//glLineWidth(3);
	glDrawArrays(GL_LINES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}


void OverlayRenderer::DrawLine(float x1, float y1, float x2, float y2) {
	vertex2 Vertices[] = {
		{x1, y1},
		{x2, y2},
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	//glLineWidth(3);
	glDrawArrays(GL_LINES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);	
}

#pragma mark -
#pragma	mark Texture handling
void OverlayRenderer::setTexture(int textureID, void *imageData, int width, int height) {
	glBindTexture(GL_TEXTURE_2D, m_textures[textureID]);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR); 
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
}