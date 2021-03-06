//
//  mainApp.cpp
//  OculusEye
//
//  Created by Jonathan Cole on 9/25/14.
//
//

#include "mainApp.h"
#include "Globals.h"


/**
 * Called once at the start of the application.
 */
void mainApp::setup(){
    
    ofDisableArbTex();
        ofFbo::Settings tmpSettings = ofFbo::Settings();
        tmpSettings.width			= TARGET_RES_X;
        tmpSettings.height			= TARGET_RES_Y;
        tmpSettings.internalformat	= GL_RGBA;
        tmpSettings.textureTarget	= GL_TEXTURE_2D;
        tmpSettings.numSamples		= 0;
        mainFbo.allocate(tmpSettings);
    ofEnableArbTex();
    
    LoadBundles();
    
    //Set the minimum type of log that is printed (lower priority logs will be ignored)
    ofSetLogLevel( OF_LOG_NOTICE );
    
    char pathBuf[ PATH_MAX ];
    printf("CWD: %s\n", getcwd(pathBuf, 512));
    
    //string cmd = "ls ../../../";
    //string cmd_output = GetStdoutFromCommand(cmd);
    //printf("%s\n%s", cmd.c_str(), cmd_output.c_str());
    
    ofLog(OF_LOG_VERBOSE, "OpenCV build information:\n");
    ofLog(OF_LOG_VERBOSE, "%s\n", cv::getBuildInformation().c_str());
    
    cv::ipp::setUseIPP(true);
    printf("Using IPP: %s\n", cv::ipp::useIPP() ? "true" : "false");
    
    ofLog(OF_LOG_NOTICE, " OpenCL acceleration is %s ", cv::ocl::haveOpenCL() ? "available" : "not available");
    ofLog(OF_LOG_NOTICE, " OpenCL acceleration %s ", USE_OPENCL ? "requested" : "not requested");
    cv::ocl::setUseOpenCL(USE_OPENCL);
    if(USE_OPENCL){
        printf("Using OpenCL: %s\n", cv::ocl::useOpenCL() ? "true" : "false");
        
        //OpenCL information from OpenCL itself
        /*
        char name[128];
        dispatch_queue_t queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU, NULL);
        if (queue == NULL) {
            queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_CPU, NULL);
        }
        cl_device_id gpu = gcl_get_device_id_with_dispatch_queue(queue);
        clGetDeviceInfo(gpu, CL_DEVICE_NAME, 128, name, NULL);
        fprintf(stdout, "Created a dispatch queue using: %s\n", name);
         */
        
        std::vector<cv::ocl::PlatformInfo> platforms;
        cv::ocl::getPlatfomsInfo(platforms);
        for(int i=0; i<platforms.size(); i++){
            printf("  Platform %i of %lu\n", i, platforms.size()-1);
            printf("    Name:     %s\n", platforms[i].name().c_str());
            printf("    Vendor:   %s\n", platforms[i].vendor().c_str());
            printf("    Device:   %i\n", platforms[i].deviceNumber());
            printf("    Version:  %s\n", platforms[i].version().c_str());
        }
    }
    
    ofLog(OF_LOG_NOTICE, " CPUs available:    %2.i", cv::getNumberOfCPUs());
    ofLog(OF_LOG_NOTICE, " Threads available: %2.i", cv::getNumThreads());
    
    #if LAUNCH_FULLSCREEN
        //TODO: Why does the camera fps go down when I use this?
        //Set fullscreen and change resolution.
        changeScreenRes(TARGET_RES_X, TARGET_RES_Y);
        SetBorderlessFullscreen(true);
    #endif
    isBorderlessFullscreen = LAUNCH_FULLSCREEN;
    
    ofSetFrameRate(TARGET_FRAMERATE);
    ofLog(OF_LOG_NOTICE, " Target framerate set to %i", TARGET_FRAMERATE);
    
    //useVSync = ENABLE_VSYNC;
    //ofSetVerticalSync(useVSync);
    //ofLog(OF_LOG_NOTICE, " Vertical sync is %s ", useVSync ? "on" : "off");
    
    oculusRift.init(TARGET_RES_X, TARGET_RES_Y, 0); //1280, 800, 4
	oculusRift.setPosition(0, 0, 0);
    
    //Set up Oculus Rift
    oculusRift.interOcularDistance = -0.65f; //IPD of 0.65 is average
    
    eyeFPSGraph = PerformanceGraph("Eye FPS", ofGetWindowWidth() - 70, ofGetWindowHeight() - 15);
    
    stereoMouseCursor.loadImage("cursor_mac_default.png");
    noseLeft.loadImage("images/Nose_Left.png");
    noseRight.loadImage("images/Nose_Right.png");
    
    //Set up GUI
    CreateGUI();
    
    InitEyes();
    
}

/**
 * Loads and initializes PS3EyePlugin.
 */
void mainApp::LoadBundles(){
    NSBundle *appBundle;
    NSArray *bundlePaths;
    
    appBundle = [NSBundle mainBundle];
    bundlePaths = [appBundle pathsForResourcesOfType:@"bundle"
                                         inDirectory:@"../PlugIns"];
    cout << "Plugins: " << [bundlePaths count] << "\n";
    
    for(NSString *bundlePath in bundlePaths){
        NSLog(@"Found plugin: %@", [bundlePath stringByAbbreviatingWithTildeInPath]);
        if([[bundlePath lastPathComponent]  isEqual: @"libPS3EyeDriver.bundle"]){
            eyeBundle = [NSBundle bundleWithPath:bundlePath];
        }
    }
    
    bool loaded = [eyeBundle load];
    printf("Loaded: %s\n", loaded ? "YES" : "NO");
    Class principalClass;
    principalClass = [eyeBundle principalClass];
    
    eyeDriver = [[principalClass alloc] init];
    [eyeDriver Begin];
    
    //Begin();
}

/**
 * Create and populate an ofxTweakbar instance. Creates the windows you see on screen.
 */
void mainApp::CreateGUI(){
    
    //BUGFIX: initializes ofxTweakbars (possible fix for gray screen at launch?)
    ofxTweakbars::draw();
    
    //GUI page 1
    //printf("Init\n");
    generalSettingsBar = ofxTweakbars::create("General Settings", "General Settings");
    //printf("Init\n");
    generalSettingsStorage = new ofxTweakbarSimpleStorage(generalSettingsBar);
    
    //Define global stuff here (quirk of the ofxTweakbar API)
    generalSettingsBar -> setGlobalHelp("OculusEye by Jonathan Cole\n"
                                        "https://github.com/seieibob/OculusEye\n"
                                        "\n"
                                        "Key shortcuts:\n"
                                        "-/+ : Change IPD\n"
                                        "F   : Toggle fullscreen\n"
                                        "C   : Begin/end camera calibration\n"
                                        "ESC : Quit program"
                                        );
    generalSettingsBar -> setIconAlign(2); //1 = vertical, 2 = horizontal
    
    generalSettingsBar -> addBool("swapEyes", swapEyes) -> setLabel("Swap Eyes") -> setKey("s");
    generalSettingsBar -> addBool("Rift Distortion", oculusRift.doWarping) -> setLabel("Rift Distortion") -> setGroup("Rift Settings") -> setKey("r");
    generalSettingsBar -> addInt("Interpupillary -/+", oculusRift.ipd) -> setLabel("Interpupillary Distance [-/+]") -> setMin("-150") -> setMax("150") -> setInc("=") -> setDecr("-") -> setGroup("Rift Settings");
    generalSettingsBar -> addBool("drawNose", Globals::drawNose) -> setLabel("Draw nose") -> setGroup("Nose Settings") -> setKey("n");
    generalSettingsBar -> addInt("noseHeight", Globals::noseHeight) -> setLabel("Nose height (from bottom)") -> setMin("0") -> setMax("400") -> setGroup("Nose Settings");
    generalSettingsBar -> addFloat("noseScale", Globals::noseScale) -> setLabel("Nose scale") -> setMin(0) -> setMax(2) -> setGroup("Nose Settings");
    generalSettingsBar -> addBool("Draw Guides", drawGuides) -> setLabel("Draw Guides") -> setGroup("Debug");
    generalSettingsBar -> addBool("showPerformanceGraph", showPerformanceGraph) -> setLabel("Show Performance Graph") -> setGroup("Debug");
    generalSettingsBar -> addBool("useVSync", useVSync) -> setLabel("Use VSync (caps at 60 FPS)");
    generalSettingsBar -> addButton("Toggle Fullscreen", mainApp::fullscreenButtonCallback, this) -> setKey("f");
    generalSettingsBar -> addButton("Toggle Stereo GUI", mainApp::stereoGUIButtonCallback, this) -> setKey("g");
    //generalSettingsBar -> addBool("correctCameraDistortion", correctCameraDistortion) -> setLabel("Correct Camera Distortion");
    generalSettingsBar -> addButton("Calibrate Camera", mainApp::calibrationButtonCallback, this);
    generalSettingsBar -> addInt("GUIConvergence", &Globals::GUIConvergence) -> setLabel("GUI Convergence") -> setMin("0") -> setMax("100") -> setGroup("GUI Adjustment");
    generalSettingsBar -> addFloat("GUIHeightScale", &Globals::GUIHeightScale) -> setLabel("GUI Height Scale") -> setMin(0.3f) -> setMax(1.0f) -> setGroup("GUI Adjustment");
    generalSettingsBar -> addButton("Save output frames", mainApp::saveOutputFramesButtonCallback, this) -> setKey("o");
    
    generalSettingsStorage -> retrieve();
    generalSettingsBar -> load();
    generalSettingsStorage -> store();
    generalSettingsBar -> close();
    
    //Set settings menu properties
    generalSettingsBar -> setSize(400, 300);
    generalSettingsBar -> setColor(44, 44, 44, 220);
    generalSettingsBar -> setFontSize(2);
    
    Globals::GUIHeightScale = 0.67;
    
    //GUI page 2
    ps3EyeSettings = ofxTweakbars::create("PS3 Eye Settings", "PS3 Eye Settings");
    ps3EyeSettingsStorage = new ofxTweakbarSimpleStorage(ps3EyeSettings);
    
    ps3EyeSettings -> addBool("autoWhiteBalance", autoWhiteBalance) -> setLabel("Auto White Balance Adjustment");
    ps3EyeSettings -> addBool("autoGain", autoGain) -> setLabel("Auto Gain Adjustment");
    ps3EyeSettings -> addFloat("gain", gain) -> setLabel("Gain") -> setMin("0") -> setMax("63");
    ps3EyeSettings -> addFloat("sharpness", sharpness) -> setLabel("Sharpness") -> setMin("0") -> setMax("63");
    ps3EyeSettings -> addFloat("exposure", exposure) -> setLabel("Exposure") -> setMin("0") -> setMax("255");
    ps3EyeSettings -> addFloat("brightness", brightness) -> setLabel("Brightness") -> setMin("0") -> setMax("255");
    ps3EyeSettings -> addFloat("contrast", contrast) -> setLabel("Contrast") -> setMin("0") -> setMax("255");
    ps3EyeSettings -> addFloat("hue", hue) -> setLabel("Hue") -> setMin("0") -> setMax("255");
    ps3EyeSettings -> addFloat("blueBalance", blueBalance) -> setLabel("Blue Balance") -> setMin("0") -> setMax("255");
    ps3EyeSettings -> addFloat("redBalance", redBalance) -> setLabel("Red Balance") -> setMin("0") -> setMax("255");
    
    ps3EyeSettingsStorage -> retrieve();
    //ps3EyeSettings -> load();
    //ps3EyeSettingsStorage -> store();
    //ps3EyeSettings -> close();
    //ps3EyeSettings -> open();
    
    ps3EyeSettings -> setSize(400, 300);
    ps3EyeSettings -> setColor(44, 44, 44, 220);
    ps3EyeSettings -> setFontSize(2);
    
    //Other Settings ----------------------------------
    otherSettings = ofxTweakbars::create("Other Settings", "Other Settings");
    otherSettingsStorage = new ofxTweakbarSimpleStorage(otherSettings);
    
    otherSettings -> addBool("computeDisparityMap", computeDisparityMap) -> setLabel("Compute Disparity Map");
    otherSettings -> addBool("showDisparityMap", showDisparityMap) -> setLabel("Show Disparity Map");
    otherSettings -> addInt("stereo_lowThreshold", stereoMapper.lowThreshold) -> setLabel("Low Threshold") -> setMin("0") -> setMax("255");
    otherSettings -> addInt("stereo_highThreshold", stereoMapper.highThreshold) -> setLabel("High Threshold") -> setMin("0") -> setMax("255");
    otherSettings -> addInt("minDisparity", stereoMapper.minDisparity) -> setLabel("Min Disparity") -> setMin("-50") -> setMax("50");
    otherSettings -> addInt("numDisparities", stereoMapper.numDisparities) -> setLabel("Num Disparities") -> setStep("16") -> setMin("16") -> setMax("512");
    otherSettings -> addInt("SADWindowSize", stereoMapper.SADWindowSize) -> setLabel("SADWindowSize") -> setMin(5) -> setMax(255) -> setStep(2);
    otherSettings -> addInt("disp12MaxDiff", stereoMapper.disp12MaxDiff) -> setLabel("disp12MaxDiff") -> setMin("0") -> setMax("500");
    otherSettings -> addInt("preFilterCap", stereoMapper.preFilterCap) -> setLabel("preFilterCap") -> setMin("1") -> setMax("63");
    otherSettings -> addInt("uniquenessRatio", stereoMapper.uniquenessRatio) -> setLabel("Uniqueness Ratio") -> setMin("0") -> setMax("30");
    otherSettings -> addInt("speckleWindowSize", stereoMapper.speckleWindowSize) -> setLabel("Speckle Window Size") -> setMin("0") -> setMax("500");
    otherSettings -> addInt("speckleRange", stereoMapper.speckleRange) -> setLabel("Speckle Range") -> setMin("0") -> setMax("500");
    otherSettings -> addInt("textureThreshold", stereoMapper.textureThreshold) -> setLabel("Texture Threshold") -> setMin("0") -> setMax("5000");
    otherSettings -> addInt("blurScale", stereoMapper.blurScale) -> setLabel("Blurring Scale") -> setMin("3") -> setMax("11") -> setStep(2);
    otherSettings -> addInt("erosionIterations", stereoMapper.erosionIterations) -> setLabel("Erosion Iterations") -> setMin("0") -> setMax("5");
    otherSettings -> addInt("dilutionIterations", stereoMapper.dilutionIterations) -> setLabel("Dilution Iterations") -> setMin("0") -> setMax("5");
    
    otherSettingsStorage -> retrieve();
    otherSettings -> load();
    otherSettingsStorage -> store();
    otherSettings -> close();
    
    otherSettings -> setSize(400, 300);
    otherSettings -> setColor(44, 44, 44, 220);
    otherSettings -> setFontSize(2);
    
    //Canny Settings ----------------------------------
    cannySettings = ofxTweakbars::create("Canny Settings", "Canny Settings");
    cannySettingsStorage = new ofxTweakbarSimpleStorage(cannySettings);
    
    cannySettings -> addBool("Canny Edge Detection", doCanny) -> setLabel("Canny Edge Detection") -> setKey("e");
    cannySettings -> addList("Canny Type", &Globals::cannyType, "Greyscale, Hue, Color") -> setLabel("Canny Type");
    cannySettings -> addBool("Canny Auto Thresholding", Globals::autoCannyThresholding) -> setLabel("Auto Canny thresholding");
    cannySettings -> addFloat("Canny Min Threshold", cannyMinThreshold) -> setLabel("Canny Min Threshold") -> setMin("0") -> setMax("100");
    cannySettings -> addFloat("Canny Ratio", cannyRatio) -> setLabel("Canny Ratio") -> setMin("2") -> setMax("3");
    cannySettings -> addInt("MinContourLength", Globals::minContourLength) -> setLabel("Minimum Contour Length") -> setMin("0") -> setMax("100");
    cannySettings -> addColor3f("Edge Color", pickerColor) -> setLabel("Edge Color");
    cannySettings -> addBool("Draw Contours", drawContours) -> setLabel("Draw Contours") -> setGroup("Contour Settings");
    cannySettings -> addInt("Edge Thickness", edgeThickness) -> setLabel("Edge Thickness") -> setGroup("Contour Settings") -> setMin("-1") -> setMax("5");
    cannySettings -> addBool("Erosion/Dilution", doErosionDilution) -> setLabel("Erosion/Dilution") -> setGroup("Erosion/Dilution Settings");
    cannySettings -> addInt("Erosion Iterations", erosionIterations) -> setLabel("Erosion Iterations") -> setGroup("Erosion/Dilution Settings") -> setMin("1") -> setMax("5");
    cannySettings -> addInt("Dilution Iterations", dilutionIterations) -> setLabel("Dilution Iterations") -> setGroup("Erosion/Dilution Settings") -> setMin("1") -> setMax("5");
    cannySettings -> addFloat("Downsampling Ratio", downsampleRatio) -> setLabel("Downsampling Ratio") -> setMin("0.01") -> setMax("1.0") -> setGroup("Performance");
    cannySettings -> addBool("Adaptive Downsampling", adaptiveDownsampling) -> setLabel("Adaptive Downsampling") -> setGroup("Performance");
    cannySettings -> addInt("Subdivisions (Cores Used)", imageSubdivisions) -> setLabel("Subdivisions (Cores Used)") -> setMin("1") -> setMax("8") -> setGroup("Performance");
    cannySettings -> addBool("Show Edges Only", showEdgesOnly) -> setLabel("Show Edges Only");
    //cannySettings -> addBool("Use Random Contour Colors", Globals::useRandomLineColors) -> setLabel("Use Random Contour Colors");
    
    cannySettingsStorage -> retrieve();
    cannySettings -> load();
    cannySettingsStorage -> store();
    cannySettings -> close();
    
    cannySettings -> setSize(400, 300);
    cannySettings -> setColor(44, 44, 44, 220);
    cannySettings -> setFontSize(2);
    
}

/**
 * Called once at the end of the application.
 */
void mainApp::exit(){
    
    //Save GUI settings here
    generalSettingsStorage -> store();
    //ps3EyeSettingsStorage -> store(); //Don't do this unless you know the defaults won't be overwritten
    otherSettingsStorage -> store();
    cannySettingsStorage -> store();
    
    //Clean up
    //Stop USB update thread. Do this before deleting USB objects
    [eyeDriver End];
    [eyeDriver dealloc];
    
    delete leftEye;
    delete rightEye;
    
    //Restore screen resolution
    #if LAUNCH_FULLSCREEN
        changeScreenRes(DEFAULT_RES_X, DEFAULT_RES_Y);
    #endif
    printf("Main app cleaned up and exited.\n");
}


/**
 * Called once per frame. Calculations should go here.
 */
void mainApp::update()
{
    //Update and draw each CVEye (no synchronization)
    leftEye->update();
    rightEye->update();
    
    //Try synchronized update
    if(leftEye->sync_update && rightEye->sync_update){
        SynchronizedUpdate();
        
        //Reset for the next loop
        leftEye->sync_update = false;
        rightEye->sync_update = false;
    }
    
    //End camera calibration if it is running and both cameras have been successfully calibrated
    if(calibrating && (leftEye->calibrator->calibrated)){
        EndCameraCalibration();
    }
    
}

/**
 * Called when both CVEye objects have a new frame ready
 * (controlled by sync_update).
 */
void mainApp::SynchronizedUpdate(){
    if(computeDisparityMap){
        stereoMapper.CalculateStereoMap(leftEye->src_gray.getMat(NULL), rightEye->src_gray.getMat(NULL), swapEyes);
    }
}


/**
 * Called after Update() once per frame.
 * Here we draw the output from each CVEye to the Oculus Rift,
 * and display the GUI.
 */
void mainApp::draw()
{
    ofSetColor(255);
    
    //ofScale(1, -1, 1);
    //ofTranslate(0, -ofGetHeight(), 0);
    ofClear(255);
    
    //mainFbo.begin();
        ofSetColor(255);
        ofClear(0);
        //ofScale(1, -1, 1);
        //ofTranslate(0, -ofGetHeight(), 0);
        
        // STEP 1: DRAW CAMERA OUTPUT --------------------------------------------
        //Perform OpenCV operations on each eye and queue the results
        //to be drawn on their respective sides
        if((leftEye->initialized || leftEye->dummyImage) && renderLeftEye){
            //Queue the left CVEye's image data into the oculusRift FBO.
            oculusRift.leftBackground = &getImageForSide(LEFT);
            //Render into the left FBO.
            oculusRift.beginRenderSceneLeftEye();
            //Draw geometry here if you want
            if(Globals::useStereoGUI){
                //ofxTweakbars::draw();
            }
            oculusRift.endRenderSceneLeftEye();
        }
        if((rightEye->initialized || leftEye->dummyImage) && renderRightEye){
            
            //Queue the right CVEye's image data into the oculusRift FBO.
            oculusRift.rightBackground = &getImageForSide(RIGHT);
            //Render into the right FBO.
            oculusRift.beginRenderSceneRightEye();
            //Draw geometry here if you want
            if(Globals::useStereoGUI){
                //ofxTweakbars::draw();
            }
            oculusRift.endRenderSceneRightEye();
        }
        
        //Set opacity to full and draw both eyes at once.
        ofSetColor( 255 );
        oculusRift.draw( ofVec2f(0,0), ofVec2f( TARGET_RES_X, TARGET_RES_Y ) );
        //Draw a nose
        if(Globals::drawNose){
            DrawNose();
        }
        
        // STEP 2: DRAW USER GRAPHICS --------------------------------------------

        if(showDisparityMap){
            DrawCVMat(stereoMapper.stereoMap, OF_IMAGE_GRAYSCALE, 0, 0, "Disparity Map");
        }
        
        //mainFBO.end();
        //mainFBO.draw(0, 0, ofGetWidth(), ofGetHeight());
        
        //Draw the GUI
        if(!Globals::useStereoGUI){
            ofxTweakbars::draw();
        }
        
        //If we're calibrating the camera, clear the screen and draw the calibration checkerboard and preview.
        if(calibrating){
            ofClear(0);

            //Load and draw the checkerboard
            cv::Mat checkerboard = cv::imread("../../../data/images/CalibrationCheckerboard.png", cv::IMREAD_ANYCOLOR);
            DrawCVMat(checkerboard, OF_IMAGE_COLOR, 0, 0);
            
            //Make text for the image with information about the capture process
            std::ostringstream stringStream;
            stringStream << " Calibrating...\n";
            stringStream << "(press C to stop)\n";
            stringStream << "Frames Captured: " << leftEye->calibrator->successes << "/" << leftEye->calibrator->numBoards;
            std::string caption = stringStream.str();
            
            //Draw the camera view
            DrawCVMat(leftEye->dest.getMat(NULL), OF_IMAGE_COLOR, checkerboard.cols, 0, 240, 180, caption);
        }
    //mainFbo.end();
    //mainFbo.draw(0, 0, 1280, ofGetHeight());
    
    //ofScale(1, -1, 1);
    //ofTranslate(0, -ofGetHeight(), 0);
    
    
    // STEP 3: DRAW DEBUG (topmost layer) ------------------------------------
    
    //Draw debug text in top-right
    string str = "app fps: ";
    str += ofToString(ofGetFrameRate(), 2) + "\n";
    //if(leftEye->initialized || leftEye->dummyImage) str += "left eye fps: " + ofToString(leftEye->camFps, 2) + "\n";
    if(leftEye->screenMessage != "") str += "left eye: " + leftEye->screenMessage + "\n";
    //if(rightEye->initialized || leftEye->dummyImage) str += "right eye fps: " + ofToString(rightEye->camFps, 2) + "\n";
    if(rightEye->screenMessage != "") str += "right eye: " + rightEye->screenMessage + "\n";
    ofDrawBitmapString(str, 10, 15);
    
    //Draw downsampling information to screen
    if(adaptiveDownsampling){
        string dsLabel = "Adaptive Downsample Ratio: ";
        dsLabel += ofToString(leftEye->adaptedDownsampleRatio, 2) + "\n";
        ofDrawBitmapString(dsLabel, 10, ofGetHeight() - 10);
    }
    
    //Draw vertical/horizontal guides for checking eye alignment at a glance
    if(drawGuides){
        ofPolyline vLine;
        vLine.addVertex(ofGetWidth()/2.0f, 0.0f);
        vLine.addVertex(ofGetWidth()/2.0f, ofGetHeight());
        vLine.draw();
        
        ofPolyline hLine;
        hLine.addVertex(0.0f, ofGetHeight()/2.0f);
        hLine.addVertex(ofGetWidth(), ofGetHeight()/2.0f);
        hLine.draw();
    }
    
    //Draw performance graph for eye
    if(showPerformanceGraph){
        eyeFPSGraph.SetPosition(ofGetWindowWidth() - 70, ofGetWindowHeight() - 15);
        eyeFPSGraph.Enqueue((leftEye->camFps + rightEye->camFps) / 2.0f);
        eyeFPSGraph.Draw();
    }
    
    if(Globals::useStereoGUI){
        DrawStereoMouse();
    }
    
}

/**
 * Returns the image for the left or right side of the
 * screen based on isSwapped.
 */
ofImage& mainApp::getImageForSide(EyeSide side){
    bool isSwapped = swapEyes;
    //if(duplicateEyes) return leftEye->finalImage;
    if(side == LEFT){
        if(isSwapped) return rightEye->finalImage;
        else return leftEye->finalImage;
    }
    else{
        if(isSwapped) return leftEye -> finalImage;
        else return rightEye->finalImage;
    }
}

//--------------------------------------------------------------
//CVEye methods

/**
 * Creates the CVEye instances that manage camera data and starts
 * the thread that polls the USB ports.
 */
void mainApp::InitEyes(){
    
    int camerasDetected = [eyeDriver GetCameraCount];
    // list out the devices
    printf("Eye cameras detected: %i\n", camerasDetected );
    
    if(camerasDetected > 0){
        //Initialize the camera polling thread
        [eyeDriver InitDriver];
    }
    
    leftEye = new CVEye(0, ((PS3EyePlugin *) eyeDriver), true);
    rightEye = new CVEye(1, ((PS3EyePlugin *) eyeDriver), false);
    
    
    //Pull default values from the camera hardware and update the GUI / CVEyes present
    if([eyeDriver LeftEyeInitialized] || [eyeDriver RightEyeInitialized]){
        autoWhiteBalance = [eyeDriver getAutoWhiteBalance];
        autoGain = [eyeDriver getAutoGain];
        gain = [eyeDriver getGain];
        sharpness = [eyeDriver getSharpness];
        exposure = [eyeDriver getExposure];
        brightness = [eyeDriver getBrightness];
        contrast = [eyeDriver getContrast];
        hue = [eyeDriver getHue];
        blueBalance = [eyeDriver getBlueBalance];
        redBalance = [eyeDriver getRedBalance];
        
        UpdateCameraSettings();
    }
    
    UpdateEyeValues(leftEye);
    UpdateEyeValues(rightEye);
    
}

/**
 * Draws a cv::Mat directly to the screen via OpenFrameworks.
 */
void mainApp::DrawCVMat(const cv::Mat& mat, ofImageType type, int x, int y, string caption){
    DrawCVMat(mat, type, x, y, mat.cols, mat.rows, caption);
}

/**
 * Draws a cv::Mat directly to the screen via OpenFrameworks.
 */
void mainApp::DrawCVMat(const cv::Mat& mat, ofImageType type, int x, int y, int w, int h, string caption){
    
    //Draw background box
    int borderWidth = 2;
    ofSetColor(255, 255, 255); //Box color
    ofDrawPlane(x-borderWidth, y-borderWidth, w + (borderWidth*2), h + (borderWidth*2) + 10);
    
    //Draw image from mat
    ofImage output;
    output.allocate(mat.cols, mat.rows, type);
    output.setFromPixels(mat.data, mat.cols, mat.rows, type);
    output.draw(x, y, w, h);
    
    //Draw the caption if available
    ofSetColor(255, 255, 255); //Text color
    if(caption != ""){
        ofDrawBitmapString(caption, x, y + h + 10);
    }
}


/**
 * Updates the values for the PS3 Eye firmware located on the device.
 * Very slow due to USB writes. Use sparingly.
 */
void mainApp::UpdateCameraSettings(){
    
    if([eyeDriver LeftEyeInitialized] || [eyeDriver RightEyeInitialized]){
        [eyeDriver setAutoWhiteBalance:autoWhiteBalance];
        [eyeDriver setAutoGain:autoGain];
        [eyeDriver setGain:gain];
        [eyeDriver setSharpness:sharpness];
        [eyeDriver setExposure:exposure];
        [eyeDriver setBrightness:brightness];
        [eyeDriver setContrast:contrast];
        [eyeDriver setHue:hue];
        [eyeDriver setBlueBalance:blueBalance];
        [eyeDriver setRedBalance:redBalance];
    }
    
}

/**
 * Sends GUI values to the CVEye instances.
 */
void mainApp::UpdateEyeValues(CVEye *eye){
    eye->doCanny = doCanny;
    eye->cannyMinThreshold = cannyMinThreshold;
    eye->cannyRatio = cannyRatio;
    eye->edgeThickness = edgeThickness;
    eye->showEdgesOnly = showEdgesOnly;
    eye->guiLineColor = cv::Scalar(pickerColor[0] * 255.0f, pickerColor[1] * 255.0f, pickerColor[2] * 255.0f);
    eye->doErosionDilution = doErosionDilution;
    eye->dilutionIterations = dilutionIterations;
    eye->erosionIterations = erosionIterations;
    eye->downsampleRatio = downsampleRatio;
    eye->adaptiveDownsampling = adaptiveDownsampling;
    eye->imageSubdivisions = imageSubdivisions;
    eye->drawContours = drawContours;
    ofSetVerticalSync(useVSync);
}

//GUI button callback - begin camera calibration
void TW_CALL mainApp::calibrationButtonCallback(void* pApp) {
    mainApp* app = static_cast<mainApp*>(pApp);
    app->BeginCameraCalibration();
}

void mainApp::BeginCameraCalibration(){
    calibrating = true;
    if(leftEye->initialized){
        leftEye->calibrator->BeginCalibration();
        leftEye->screenMessage = "Calibrating...";
    }
    if(rightEye->initialized){
        //rightEye->calibrator.BeginCalibration();
        rightEye->screenMessage = "Calibrating...";
    }
}

void mainApp::EndCameraCalibration(bool stopEarly){
    if(calibrating && stopEarly){
        leftEye->calibrator->EndCalibration(true);
        //rightEye->calibrator->EndCalibration(true);
        
    }
    leftEye->screenMessage = "";
    rightEye->screenMessage = "";
    calibrating = false;
}

/**
 * GUI button callback - toggle fullscreen
 */
void TW_CALL mainApp::fullscreenButtonCallback(void* pApp) {
    mainApp* app = static_cast<mainApp*>(pApp);
    app->ToggleBorderlessFullscreen();
}

/**
 * Toggles borderless fullscreen on and off.
 */
void mainApp::ToggleBorderlessFullscreen(){
    isBorderlessFullscreen = !isBorderlessFullscreen;
    SetBorderlessFullscreen(isBorderlessFullscreen);
}

/**
 * Sets borderless fullscreen directly through Cocoa.
 * Avoids VSync bug (doubles with two monitors).
 * See https://gist.github.com/ofZach/7808368
 */
void mainApp::SetBorderlessFullscreen(bool useFullscreen){
    NSWindow *window = (NSWindow *)ofGetCocoaWindow();
    //Enable fullscreen in another Space
    [window setCollectionBehavior:(NSWindowCollectionBehaviorFullScreenPrimary)];
    //[window toggleFullScreen:nil];
    
    
    //Fullscreen
    if(useFullscreen){
        [window setStyleMask:NSBorderlessWindowMask];
        //[window setLevel:NSFloatingWindowLevel];
        window.level = NSMainMenuWindowLevel + 1;
        ofSetWindowShape(TARGET_RES_X, TARGET_RES_Y);
        ofSetWindowPosition(RIFT_MONITOR_X, 1); //Set it one pixel down from true fullscreen to fool OpenGL into giving me more FPS when using VSync
    }
    //Windowed
    else{
        window.level = 0;
        //window.level = NSMainMenuWindowLevel - 1;
        ofSetWindowPosition(0,200);
        ofSetWindowShape(DEFAULT_RES_X, DEFAULT_RES_Y);
        [window setStyleMask: NSResizableWindowMask| NSClosableWindowMask | NSMiniaturizableWindowMask | NSTitledWindowMask];
        //[window makeKeyAndOrderFront:nil];
    }
    isBorderlessFullscreen = useFullscreen;
    //Focus is lost due to a bug in OpenFrameworks; this returns focus to the window
    //(see https://github.com/openframeworks/openFrameworks/issues/2174)
    [window makeFirstResponder:window.contentView];
    
}

//GUI button callback - toggle stereo GUI
void TW_CALL mainApp::stereoGUIButtonCallback(void* pApp) {
    mainApp* app = static_cast<mainApp*>(pApp);
    app->ToggleStereoGUI();
}

void mainApp::ToggleStereoGUI(){
    Globals::useStereoGUI = !Globals::useStereoGUI;
    //Set up stereo gui
    if(Globals::useStereoGUI){
        ofHideCursor();
        ofxTweakbars::SetWindowSize(ofGetWidth()/2, ofGetHeight());
    }
    //Restore mono gui
    else{
        ofShowCursor();
        ofxTweakbars::SetWindowSize(ofGetWidth(), ofGetHeight());
    }
}

void TW_CALL mainApp::saveOutputFramesButtonCallback(void* pApp){
    mainApp* app = static_cast<mainApp*>(pApp);
    app->saveOutputFrames();
}

void mainApp::saveOutputFrames(){
    leftEye->outputFrameSteps = true;
}

//--------------------------------------------------------------
// UI Methods
/**
 * This method fires when a key is pressed.
 */
void mainApp::keyPressed(int key){
    switch(key) {
        case 'c': if(!calibrating) BeginCameraCalibration(); else EndCameraCalibration(true); break;

    }
    UpdateEyeValues(leftEye);
    UpdateEyeValues(rightEye);
    UpdateCameraSettings();
    
}

/**
 * This method fires when a key is released.
 */
void mainApp::keyReleased(int key){
    UpdateEyeValues(leftEye);
    UpdateEyeValues(rightEye);
    UpdateCameraSettings();
}

/**
 * This method fires when the mouse is moved.
 */
void mainApp::mouseMoved(int x, int y ){

}

/**
 * This method fires when the mouse is dragged.
 */
void mainApp::mouseDragged(int x, int y, int button){
    if(leftEye){ UpdateEyeValues(leftEye); }
    if(rightEye){ UpdateEyeValues(rightEye); }
}

/**
 * This method fires when a mouse button is down.
 */
void mainApp::mousePressed(int x, int y, int button){
    //Update values to reflect GUI state
    //These operations are expensive. Use them only when necessary.
    if(leftEye){
        UpdateEyeValues(leftEye);
    }
    if(rightEye){
        UpdateEyeValues(rightEye);
    }
    UpdateCameraSettings();
}

/**
 * This method fires when a mouse button is up.
 */
void mainApp::mouseReleased(int x, int y, int button){
    //Update values to reflect GUI state
    //These operations are expensive. Use them only when necessary.
    if(leftEye){
        UpdateEyeValues(leftEye);
    }
    if(rightEye){
        UpdateEyeValues(rightEye);
    }
    UpdateCameraSettings();
}

/**
 * This method fires when the window is resized.
 */
void mainApp::windowResized(int w, int h){

}

/**
 * This method fires when the window is dragged.
 */
void mainApp::dragEvent(ofDragInfo dragInfo){ 

}

void mainApp::DrawStereoMouse(){
    //Draw the cursor at the mouse's position
    stereoMouseCursor.draw(ofGetMouseX(), ofGetMouseY());
    
    //Draw the cursor where the mouse would appear on the other side,
    //adjusted for convergence.
    int otherSideX = ofGetMouseX();
    //Right side of screen
    if(ofGetMouseX() > ofGetWindowWidth() / 2){
        otherSideX -= ofGetWindowWidth() / 2;
        otherSideX += (Globals::GUIConvergence * 2);
        if(otherSideX <= ofGetWindowWidth() / 2)
        stereoMouseCursor.draw(otherSideX, ofGetMouseY());
    }
    //Left side of screen
    else{
        otherSideX += ofGetWindowWidth() / 2;
        otherSideX -= (Globals::GUIConvergence * 2);
        if(otherSideX > ofGetWindowWidth() / 2)
            stereoMouseCursor.draw(otherSideX, ofGetMouseY());
    }
}

/**
 * Draws a nose to the screen.
 */
void mainApp::DrawNose(){
    int y = (ofGetHeight() - noseLeft.height) - Globals::noseHeight;
    int width = noseLeft.width * Globals::noseScale;
    int height = noseLeft.height * Globals::noseScale;
    noseLeft.draw(ofGetWidth()/2 - (noseLeft.width * Globals::noseScale), y, width, height);
    noseRight.draw(ofGetWidth()/2, y, width, height);
}

//--------------------------------------------------------------
void mainApp::gotMessage(ofMessage msg){
    
}

/**
 * Prints out the output from a system command.
 * From https://www.jeremymorgan.com/tutorials/c-programming/how-to-capture-the-output-of-a-linux-command-in-c/
 */
string mainApp::GetStdoutFromCommand(string cmd) {
    
    string data;
    FILE * stream;
    const int max_buffer = 256;
    char buffer[max_buffer];
    cmd.append(" 2>&1");
    
    stream = popen(cmd.c_str(), "r");
    if (stream) {
        while (!feof(stream))
            if (fgets(buffer, max_buffer, stream) != NULL) data.append(buffer);
        pclose(stream);
    }
    return data;
}

