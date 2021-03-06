//
//  mainApp.h
//  OculusEye
//
//  Created by Jonathan Cole on 9/25/14.
//
//

#pragma once

#include "ofMain.h"
#include "ofxOculusRift.h"
#include "ofxTweak.h"

#include "CVEye.h"
#include "programSettings.h"
#include "screenConfig.h"
#include "CVPerformance.h"
#include "StereoDepthMapper.h"

#include <opencv2/core.hpp>
#include <opencv2/core/utility.hpp>
#include "opencv2/core/core.hpp"
#include <opencv2/core/ocl.hpp>

class mainApp : public ofBaseApp {
public:
    //OpenFrameworks------------------------------
    void setup();
    void exit();
    void update();
    void draw();

    void keyPressed  (int key);
    void keyReleased(int key);
    void mouseMoved(int x, int y );
    void mouseDragged(int x, int y, int button);
    void mousePressed(int x, int y, int button);
    void mouseReleased(int x, int y, int button);
    void windowResized(int w, int h);
    void dragEvent(ofDragInfo dragInfo);
    void gotMessage(ofMessage msg);
    
    bool isBorderlessFullscreen;
    void ToggleBorderlessFullscreen();
    void SetBorderlessFullscreen(bool useFullscreen);

    ofImage leftVideoImage, leftFinalImage;
    ofImage rightVideoImage, rightFinalImage;
    
    bool duplicateEyes;
    
    void SynchronizedUpdate();
    void DrawCVMat(const cv::Mat &mat, ofImageType type, int x, int y, string caption = "");
    void DrawCVMat(const cv::Mat &mat, ofImageType type, int x, int y, int w, int h, string caption = "");
    
    bool useVSync;

    //PS3 Eye--------------
    void LoadBundles();
    NSBundle *eyeBundle;
    id eyeDriver; //<PS3EyePlugin>
    
    void InitEyes();
    //Camera controls
    bool autoWhiteBalance;
    bool autoGain;
    float gain;
    float sharpness;
    float exposure;
    float brightness;
    float contrast;
    float hue;
    float blueBalance;
    float redBalance;

    //Oculus Rift--------------
    ofxOculusRift oculusRift;
    bool doRiftDistortion;
    bool swapEyes;
    
    enum EyeSide{
        LEFT = 1,
        RIGHT = 2
    };
    ofImage& getImageForSide(EyeSide side);

    //OpenCV--------------------
    float cannyRatio = 3.0f;
    //Raise/lower this number to change Canny sensitivity
    float cannyMinThreshold = 50.0f;
    bool doCanny;
    bool showEdgesOnly;
    //The color specified by the GUI color picker
    float pickerColor[4];
    //Thickness of edges. Set to -1 to have OpenCV try to fill closed contours.
    int edgeThickness = 2;
    bool doErosionDilution;
    int erosionIterations = 1;
    int dilutionIterations = 1;
    float downsampleRatio = 0.5f;
    //Auto-adjustment of downsampleRatio based on framerate
    bool adaptiveDownsampling = false;
    int imageSubdivisions = 1;
    //If false, only canny output is drawn
    bool drawContours = true;

    bool renderLeftEye = true;
    bool renderRightEye = true;

    CVEye *leftEye;
    CVEye *rightEye;

    //GUI-----------------------
    void CreateGUI();
    
    ofxTweakbar *generalSettingsBar;
    ofxTweakbarSimpleStorage *generalSettingsStorage;

    ofxTweakbar *ps3EyeSettings;
    ofxTweakbarSimpleStorage *ps3EyeSettingsStorage;
    
    ofxTweakbar *otherSettings;
    ofxTweakbarSimpleStorage *otherSettingsStorage;
    
    ofxTweakbar *cannySettings;
    ofxTweakbarSimpleStorage *cannySettingsStorage;
    
    PerformanceGraph eyeFPSGraph = PerformanceGraph("Left Eye", 0.0f, 0.0f);
    bool showPerformanceGraph = false;
    
    bool drawGuides;
    
    static void TW_CALL fullscreenButtonCallback(void* pApp);
    static void TW_CALL calibrationButtonCallback(void* pApp);
    static void TW_CALL stereoGUIButtonCallback(void* pApp);
    static void TW_CALL saveOutputFramesButtonCallback(void *pApp);
    
    void saveOutputFrames();
    
    void DrawStereoMouse();
    ofImage stereoMouseCursor;
    
    void DrawNose();
    ofImage noseLeft;
    ofImage noseRight;
    
    //Other---------------------
    void UpdateEyeValues(CVEye *eye);
    void UpdateCameraSettings();
    
    bool calibrating = false;
    void BeginCameraCalibration();
    void EndCameraCalibration(bool stopEarly = false);
    bool correctCameraDistortion;
    
    StereoDepthMapper stereoMapper;
    bool computeDisparityMap = false;
    bool showDisparityMap = false;
    
    void ToggleStereoGUI();
    
    ofFbo mainFbo;
    
private:
    string GetStdoutFromCommand(string cmd);
};
