#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup() {

  string_state_map["idle"] = State::IDLE;
  string_state_map["countdown"] = State::COUNTDOWN;
  string_state_map["transition_to_filter"] = State::TRANSITION;
  string_state_map["apply_filter"] = State::APPLY_FILTER;
  string_state_map["end_screen"] = State::END_SCREEN;

  // try to grab at this size.
  camWidth = 1920;
  camHeight = 1080;

  gui.setup("parameters");
  gui.add(pixelZoom.set("pixel zoom", 10.0, 0.2, 30.0));
  gui.add(idleMaxZoom.set("idle pixel max zoom", 100.0, 10.0, 1000.0));
  gui.add(showFeed.set("show feed", true));
  gui.add(showPixels.set("show pixels", true));
  gui.add(showFilterShader.set("show filter shader", true));
  gui.add(filterGain.set("filter gain", 0.0, -0.2, 0.2));
  gui.add(filterExponent.set("filter exponent", 1.0, 0.25, 4.0));

  // get back a list of devices.
  vector<ofVideoDevice> devices = vidGrabber.listDevices();

  for (size_t i = 0; i < devices.size(); i++) {
    if (devices[i].bAvailable) {
      // log the device
      ofLogNotice() << devices[i].id << ": " << devices[i].deviceName;
    } else {
      // log the device and note it as unavailable
      ofLogNotice() << devices[i].id << ": " << devices[i].deviceName
                    << " - unavailable ";
    }
  }

  numberFont.load("fonts/Millimetre-Regular_web.ttf", 350);
  endScreenFont.load("fonts/Millimetre-Light_web.ttf", 25);

  if (!useStaticImage) {
    vidGrabber.setDeviceID(0);
    vidGrabber.setDesiredFrameRate(30);
    vidGrabber.setup(camWidth, camHeight);

    videoInverted.allocate(vidGrabber.getWidth(), vidGrabber.getHeight(),
                           OF_PIXELS_RGB);
    videoTexture.allocate(videoInverted);
    if (!flipWebcam) {
      imageFbo.allocate(vidGrabber.getWidth(), vidGrabber.getHeight());
    } else {
      imageFbo.allocate(vidGrabber.getHeight(), vidGrabber.getWidth());
    }
  } else {

    staticImage.load("static_image.jpg");
    videoInverted.allocate(staticImage.getWidth(), staticImage.getHeight(),
                           OF_PIXELS_RGB);
    videoTexture.allocate(videoInverted);

    if (!flipWebcam) {
      imageFbo.allocate(staticImage.getWidth(), staticImage.getHeight());
    } else {
      imageFbo.allocate(staticImage.getHeight(), staticImage.getWidth());
    }
  }
  filteredImageFbo.allocate(imageFbo.getWidth(), imageFbo.getHeight());

  ofSetVerticalSync(true);

  pixelShader.load("shaders/pixel_shader/shader");
  filterShader.load("shaders/filter_shader/shader");

  receiver.setup(PORT);
  sender.setup("localhost", 12371);
  // send image resolution to the server
  ofxOscMessage m;
  m.setAddress("/image_resolution");
  if (!useStaticImage) {
    m.addIntArg(vidGrabber.getWidth());
    m.addIntArg(vidGrabber.getHeight());
  } else {
    m.addIntArg(staticImage.getWidth());
    m.addIntArg(staticImage.getHeight());
  }
  sender.sendMessage(m, false);
  ofLog() << "Setup finished";

  imageFbo.begin();
  if (useStaticImage) {
    staticImage.draw(0, 0);
  } else {
    vidGrabber.draw(0, 0);
  }
  imageFbo.end();
  filteredImageFbo.begin();
  ofPushMatrix();
  if (flipWebcam) {
    ofRotateDeg(180);
  }
  filterShader.begin();
  filterShader.setUniform2f("resolution", imageFbo.getWidth(),
                            imageFbo.getHeight());
  filterShader.setUniform2f("outputResolution", filteredImageFbo.getWidth(),
                            filteredImageFbo.getHeight());
  filterShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
  filterShader.setUniform1f("invertY", 0);
  filterShader.setUniform1f("exponent", filterExponent);
  filterShader.setUniform1f("gain", filterGain);
  filterShader.setUniform1f("pixelsProcessed", 99999999);
  ofDrawRectangle(0, 0, filteredImageFbo.getWidth(),
                  filteredImageFbo.getHeight());
  filterShader.end();
  ofPopMatrix();
  filteredImageFbo.end();
}

//--------------------------------------------------------------
void ofApp::update() {
  checkOscMessages();
  ofBackground(100, 100, 100);
  if (!useStaticImage) {
    vidGrabber.update();

    if (vidGrabber.isFrameNew()) {
      ofPixels &pixels = vidGrabber.getPixels();
      for (size_t i = 0; i < pixels.size(); i++) {
        // invert the color of the pixel
        videoInverted[i] = 255 - pixels[i];
      }
      // load the inverted pixels
      videoTexture.loadData(videoInverted);
    }
  }
}

//--------------------------------------------------------------
void ofApp::draw() {
  ofSetColor(255);
  if (state == State::IDLE || state == State::COUNTDOWN) {
    // Draw the live image on the imageFbo
    imageFbo.begin();
    ofPushMatrix();
    if (flipWebcam) {
      ofTranslate(imageFbo.getWidth() / 2, imageFbo.getHeight() / 2);
      ofRotateDeg(-90);
      ofTranslate(imageFbo.getHeight() / -2, imageFbo.getWidth() / -2);
    }
    if (useStaticImage) {
      staticImage.draw(0, 0);
    } else {
      vidGrabber.draw(0, 0);
    }
    ofPopMatrix();
    imageFbo.end();

    if (showPixels) {
      pixelZoom = sin(ofGetElapsedTimef() * 1.7) * 0.125 + 0.125 +
                  (sin(ofGetElapsedTimef() * 0.43374) * 0.75 + 0.75);
      pixelZoom = 2 + pow(float(pixelZoom), 3.0) * idleMaxZoom;
      pixelShader.begin();
      pixelShader.setUniform2f("resolution", imageFbo.getWidth(),
                               imageFbo.getHeight());
      pixelShader.setUniform2f("outputResolution", ofGetWidth(), ofGetHeight());
      pixelShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
      // pixelShader.setUniform1f("zoom", (sin(ofGetElapsedTimef()) + 1.0) *
      // 500.0);
      pixelShader.setUniform1f("zoom", pixelZoom);
      pixelShader.setUniform1f("alpha", 1.0);
      ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
      pixelShader.end();
    }
    if (showFeed) {
      ofSetHexColor(0xffffff);
      float camZoom = (float(ofGetWidth()) * 0.5) / float(imageFbo.getWidth());
      glm::vec2 camPos =
          glm::vec2((ofGetWidth() - imageFbo.getWidth() * camZoom) * 0.5,
                    (ofGetHeight() - imageFbo.getHeight() * camZoom) * 0.5);
      imageFbo.draw(camPos.x, camPos.y, imageFbo.getWidth() * camZoom,
                    imageFbo.getHeight() * camZoom);
    }
    if (state == State::COUNTDOWN) {
      ostringstream s;
      s << countdownData.num;
      float w = numberFont.stringWidth(s.str());
      float h = numberFont.getLineHeight();
      numberFont.drawString(s.str(), (ofGetWidth() - w) * 0.5,
                            (ofGetHeight() + h * 0.75) * 0.5);
    }
  } else if (state == State::TRANSITION) {

    // Draw the filter shader in the background
    filterShader.begin();
    filterShader.setUniform2f("resolution", imageFbo.getWidth(),
                              imageFbo.getHeight());
    filterShader.setUniform2f("outputResolution", ofGetWidth(), ofGetHeight());
    filterShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
    filterShader.setUniform1f("invertY", 1);
    filterShader.setUniform1f("exponent", filterExponent);
    filterShader.setUniform1f("gain", filterGain);
    filterShader.setUniform1f("pixelsProcessed",
                              applyFilterData.pixelsProcessed);

    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    filterShader.end();

    // Draw the star of the show, the pixels
    float phase = (ofGetElapsedTimef() - transitionData.startTime) /
                  transitionData.duration;
    float s_phase = atan(phase);
    pixelZoom = 1 + pow(phase, 8) * (transitionData.maxZoom);

    pixelShader.begin();
    pixelShader.setUniform2f("resolution", imageFbo.getWidth(),
                             imageFbo.getHeight());
    pixelShader.setUniform2f("outputResolution", ofGetWidth(), ofGetHeight());
    pixelShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
    pixelShader.setUniform1f("zoom", pixelZoom);
    pixelShader.setUniform1f("alpha", 1.0 - pow(phase, 10));
    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    pixelShader.end();
  } else if (state == State::APPLY_FILTER) {

    // filteredImageFbo.begin();
    filterShader.begin();
    filterShader.setUniform2f("resolution", imageFbo.getWidth(),
                              imageFbo.getHeight());
    filterShader.setUniform2f("outputResolution", ofGetWidth(), ofGetHeight());
    filterShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
    filterShader.setUniform1f("invertY", 1);
    filterShader.setUniform1f("exponent", filterExponent);
    filterShader.setUniform1f("gain", filterGain);
    filterShader.setUniform1f("pixelsProcessed",
                              applyFilterData.pixelsProcessed);

    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    filterShader.end();
    // filteredImageFbo.end();
    // filteredImageFbo.draw(0, 0, ofGetWidth(), ofGetHeight());

  } else if (state == State::END_SCREEN) {

    // TEMP this can be removed when we are sure the states are progressed
    // through in order

    filteredImageFbo.begin();
    filterShader.begin();
    filterShader.setUniform2f("resolution", imageFbo.getWidth(),
                              imageFbo.getHeight());
    filterShader.setUniform2f("outputResolution", filteredImageFbo.getWidth(),
                              filteredImageFbo.getHeight());
    filterShader.setUniformTexture("tex0", imageFbo.getTextureReference(), 1);
    filterShader.setUniform1f("invertY", 0);
    filterShader.setUniform1f("exponent", filterExponent);
    filterShader.setUniform1f("gain", filterGain);
    filterShader.setUniform1f("pixelsProcessed", 99999999);
    ofDrawRectangle(0, 0, filteredImageFbo.getWidth(),
                    filteredImageFbo.getHeight());
    filterShader.end();
    filteredImageFbo.end();

    ofBackground(0);
    ofSetColor(255);

    float camZoom =
        (float(ofGetWidth()) * 0.5) / float(imageFbo.getWidth()) * 0.8;
    float margin = imageFbo.getWidth() * 0.05;
    glm::vec2 r =
        glm::vec2(imageFbo.getWidth() * camZoom + (margin * 2), ofGetHeight());
    ofDrawRectangle((ofGetWidth() - r.x) * 0.5, (ofGetHeight() - r.y) * 0.5,
                    r.x, r.y);
    // draw unaltered image
    glm::vec2 camPos =
        glm::vec2((ofGetWidth() - imageFbo.getWidth() * camZoom) * 0.5, margin);
    imageFbo.draw(camPos.x, camPos.y, imageFbo.getWidth() * camZoom,
                  imageFbo.getHeight() * camZoom);
    camPos.y += filteredImageFbo.getHeight() * camZoom + margin;
    filteredImageFbo.draw(camPos.x, camPos.y,
                          filteredImageFbo.getWidth() * camZoom,
                          filteredImageFbo.getHeight() * camZoom);
    camPos.y += filteredImageFbo.getHeight() * camZoom + margin;

    // endScreenFont.drawString(
    //     "Du applicerade filtret på\nbilden genom att köra\n"
    //     "1 728 000 instruktioner!",
    //     50, ofGetHeight() * 0.5);
    ostringstream s;
    long pixels = imageFbo.getWidth() * imageFbo.getHeight();
    ofSetColor(0);
    s << "#" << pixels * 5 << " instruktioner     #" << pixels
      << " pixlar\n#filter";
    endScreenFont.drawString(s.str(), camPos.x,
                             (ofGetHeight() - camPos.y) * 0.5 + camPos.y);
  }
  // videoTexture.draw(20 + camWidth, 20, camWidth, camHeight);

  gui.draw();
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key) {
  // in fullscreen mode, on a pc at least, the
  // first time video settings the come up
  // they come up *under* the fullscreen window
  // use alt-tab to navigate to the settings
  // window. we are working on a fix for this...

  // Video settings no longer works in 10.7
  // You'll need to compile with the 10.6 SDK for this
  // For Xcode 4.4 and greater, see this forum post on instructions on
  // installing the SDK http://forum.openframeworks.cc/index.php?topic=10343
  if (key == 's' || key == 'S') {
    vidGrabber.videoSettings();
  }
}

//--------------------------------------------------------------
void ofApp::keyReleased(int key) {}

void ofApp::transition_to_state(State new_state) { state = new_state; }

void ofApp::checkOscMessages() {

  // check for waiting messages
  while (receiver.hasWaitingMessages()) {

    // get the next message
    ofxOscMessage m;
    receiver.getNextMessage(m);

    // check for mouse moved message
    if (m.getAddress() == "/pixelsToProcess") {
      int pixelsToProcess = m.getArgAsInt(0);
    } else if (m.getAddress() == "/transition_to_state") {
      string state_name = m.getArgAsString(0);
      auto it = string_state_map.find(state_name);
      if (it != string_state_map.end()) {
        transition_to_state(it->second);
        if (it->second == State::TRANSITION) {
          transitionData.duration = m.getArgAsFloat(1);
          transitionData.zoom = 1;
          transitionData.startTime = ofGetElapsedTimef();
          // send image resolution to the server
          ofxOscMessage m;
          m.setAddress("/image_resolution");
          if (!useStaticImage) {
            m.addIntArg(vidGrabber.getWidth());
            m.addIntArg(vidGrabber.getHeight());
          } else {
            m.addIntArg(staticImage.getWidth());
            m.addIntArg(staticImage.getHeight());
          }
          sender.sendMessage(m, false);
        } else if (it->second == State::APPLY_FILTER) {
          applyFilterData.pixelsProcessed = 0;
        } else if (it->second == State::END_SCREEN) {
          // Draw filtered image to fbo
          filteredImageFbo.begin();
          filterShader.begin();
          filterShader.setUniform2f("resolution", imageFbo.getWidth(),
                                    imageFbo.getHeight());
          filterShader.setUniform2f("outputResolution",
                                    filteredImageFbo.getWidth(),
                                    filteredImageFbo.getHeight());
          filterShader.setUniformTexture("tex0", imageFbo.getTextureReference(),
                                         1);
          filterShader.setUniform1f("invertY", 0);
          filterShader.setUniform1f("exponent", filterExponent);
          filterShader.setUniform1f("gain", filterGain);
          filterShader.setUniform1f("pixelsProcessed", 99999999);
          ofDrawRectangle(0, 0, filteredImageFbo.getWidth(),
                          filteredImageFbo.getHeight());
          filterShader.end();
          filteredImageFbo.end();
        }
        ofLog() << "Changed state to " << state_name;
      } else {
        ofLog() << "ERROR: unparsable state name: " << state_name;
      }
      // State new_state = string_state_map[state_name];
      // switch (state_name) {
      // case "idle":
      //   new_state = State::IDLE;
      //   break;
      // case "transition_to_filter":
      //   new_state = State::TRANSITION;
      //   break;
      // case "countdown":
      //   new_state = State::COUNTDOWN;
      //   break;
      // case "apply_filter":
      //   new_state = State::APPLY_FILTER;
      //   break;
      // case "end_screen":
      //   new_state = State::END_SCREEN;
      //   break;
      // }
    } else if (m.getAddress() == "/countdown") {
      countdownData.num = m.getArgAsInt(0);
    } else if (m.getAddress() == "/pixels_processed") {
      applyFilterData.pixelsProcessed = m.getArgAsInt(0);
    }
    // check for an image being sent
    // note: the size of the image depends greatly on your network buffer
    // sizes, if an image is too big the message won't come through
    else if (m.getAddress() == "/image") {
      ofBuffer buffer = m.getArgAsBlob(0);
    } else {

      // unrecognized message: display on the bottom of the screen
      string msgString;
      msgString = m.getAddress();
      msgString += ":";
      for (size_t i = 0; i < m.getNumArgs(); i++) {

        // get the argument type
        msgString += " ";
        msgString += m.getArgTypeName(i);
        msgString += ":";

        // display the argument - make sure we get the right type
        if (m.getArgType(i) == OFXOSC_TYPE_INT32) {
          msgString += ofToString(m.getArgAsInt32(i));
        } else if (m.getArgType(i) == OFXOSC_TYPE_FLOAT) {
          msgString += ofToString(m.getArgAsFloat(i));
        } else if (m.getArgType(i) == OFXOSC_TYPE_STRING) {
          msgString += m.getArgAsString(i);
        } else {
          msgString += "unhandled argument type " + m.getArgTypeName(i);
        }
      }

      ofLogVerbose() << msgString;
    }
  }
}
//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y) {}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button) {}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button) {}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button) {}

//--------------------------------------------------------------
void ofApp::mouseEntered(int x, int y) {}

//--------------------------------------------------------------
void ofApp::mouseExited(int x, int y) {}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h) {}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg) {}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo) {}