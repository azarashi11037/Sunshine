/**
 * @file src/platform/macos/av_video.m
 * @brief Definitions for video capture on macOS.
 */
// local includes
#import "av_video.h"

@implementation AVVideo

// XXX: Currently, this function only returns the screen IDs as names,
// which is not very helpful to the user. The API to retrieve names
// was deprecated with 10.9+.
// However, there is a solution with little external code that can be used:
// https://stackoverflow.com/questions/20025868/cgdisplayioserviceport-is-deprecated-in-os-x-10-9-how-to-replace
+ (NSArray<NSDictionary *> *)displayNames {
  CGDirectDisplayID displays[kMaxDisplays];
  uint32_t count;
  if (CGGetActiveDisplayList(kMaxDisplays, displays, &count) != kCGErrorSuccess) {
    return [NSArray array];
  }

  NSMutableArray *result = [NSMutableArray array];

  for (uint32_t i = 0; i < count; i++) {
    NSString *displayName = [self getDisplayName:displays[i]];
    if (!displayName) {
      displayName = [NSString stringWithFormat:@"%u", displays[i]];
    }

    [result addObject:@{
      @"id": [NSNumber numberWithUnsignedInt:displays[i]],
      @"name": [NSString stringWithFormat:@"%d", displays[i]],
      @"displayName": displayName,
    }];
  }

  return [NSArray arrayWithArray:result];
}

+ (NSString *)getDisplayName:(CGDirectDisplayID)displayID {
  for (NSScreen *screen in [NSScreen screens]) {
    if ([screen.deviceDescription[@"NSScreenNumber"] isEqualToNumber:[NSNumber numberWithUnsignedInt:displayID]]) {
      return screen.localizedName;
    }
  }
  return nil;
}

- (BOOL)prepareScreenCaptureFilter {
  if (@available(macOS 15.0, *)) {
    __block SCShareableContent *shareableContent = nil;
    __block NSError *shareableContentError = nil;
    dispatch_semaphore_t contentSignal = dispatch_semaphore_create(0);

    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      shareableContent = [content retain];
      shareableContentError = [error retain];
      dispatch_semaphore_signal(contentSignal);
    }];

    if (dispatch_semaphore_wait(contentSignal, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC)) != 0) {
      NSLog(@"Sunshine HDR: timed out while enumerating ScreenCaptureKit displays");
      return NO;
    }

    if (!shareableContent) {
      NSLog(@"Sunshine HDR: failed to enumerate ScreenCaptureKit displays: %@", shareableContentError);
      [shareableContentError release];
      return NO;
    }

    SCDisplay *targetDisplay = nil;
    for (SCDisplay *display in shareableContent.displays) {
      if (display.displayID == self.displayID) {
        targetDisplay = display;
        break;
      }
    }

    if (!targetDisplay) {
      NSLog(@"Sunshine HDR: display id %u is unavailable to ScreenCaptureKit", self.displayID);
      [shareableContent release];
      [shareableContentError release];
      return NO;
    }

    self.screenContentFilter = [[[SCContentFilter alloc] initWithDisplay:targetDisplay excludingWindows:@[]] autorelease];
    [shareableContent release];
    [shareableContentError release];
    return self.screenContentFilter != nil;
  }

  NSLog(@"Sunshine HDR: ScreenCaptureKit HDR requires macOS 15 or newer");
  return NO;
}

- (id)initWithDisplay:(CGDirectDisplayID)displayID frameRate:(int)frameRate hdr:(BOOL)hdr {
  self = [super init];

  CGDisplayModeRef mode = CGDisplayCopyDisplayMode(displayID);
  if (!mode) {
    [self release];
    return nil;
  }

  self.displayID = displayID;
  self.hdrCaptureEnabled = hdr;
  self.pixelFormat = hdr ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_32BGRA;
  self.frameWidth = (int) CGDisplayModeGetPixelWidth(mode);
  self.frameHeight = (int) CGDisplayModeGetPixelHeight(mode);
  self.minFrameDuration = CMTimeMake(1, frameRate);
  self.captureStopRequested = NO;
  CFRelease(mode);

  if (self.hdrCaptureEnabled) {
    if (![self prepareScreenCaptureFilter]) {
      [self release];
      return nil;
    }

    return self;
  }

  self.session = [[AVCaptureSession alloc] init];
  self.videoOutputs = [[NSMapTable alloc] init];
  self.captureCallbacks = [[NSMapTable alloc] init];
  self.captureSignals = [[NSMapTable alloc] init];

  AVCaptureScreenInput *screenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:self.displayID];
  [screenInput setMinFrameDuration:self.minFrameDuration];

  if ([self.session canAddInput:screenInput]) {
    [self.session addInput:screenInput];
  } else {
    [screenInput release];
    return nil;
  }

  [self.session startRunning];

  return self;
}

- (void)dealloc {
  [self.screenStream stopCaptureWithCompletionHandler:nil];
  self.screenFrameCallback = nil;
  [self.screenStream release];
  [self.screenContentFilter release];
  [self.videoOutputs release];
  [self.captureCallbacks release];
  [self.captureSignals release];
  [self.session stopRunning];
  [super dealloc];
}

- (void)setFrameWidth:(int)frameWidth frameHeight:(int)frameHeight {
  self.frameWidth = frameWidth;
  self.frameHeight = frameHeight;
}

- (void)finishScreenCaptureStoppingStream:(BOOL)stopStream
                                   failed:(BOOL)failed
                                    error:(NSError *)error {
  SCStream *stream = nil;
  dispatch_semaphore_t signal = nil;
  BOOL alreadyFinishing = NO;

  @synchronized(self) {
    self.captureFailed = self.captureFailed || failed;
    self.screenFrameCallback = nil;
    signal = self.screenCaptureSignal;
    self.screenCaptureSignal = nil;

    alreadyFinishing = self.screenCaptureFinishing;
    if (!alreadyFinishing) {
      self.screenCaptureFinishing = YES;
      stream = [self.screenStream retain];
    }
  }

  // Wake display.mm immediately. ScreenCaptureKit's asynchronous stop
  // completion can be delayed indefinitely during client disconnect.
  if (signal) {
    dispatch_semaphore_signal(signal);
  }

  if (alreadyFinishing) {
    return;
  }

  if (error) {
    NSLog(@"Sunshine HDR: ScreenCaptureKit stream error: %@", error);
  }

  void (^finish)(NSError *) = ^(NSError *stopError) {
    if (stopError) {
      NSLog(@"Sunshine HDR: failed to stop ScreenCaptureKit stream cleanly: %@", stopError);
    }

    @synchronized(self) {
      if (self.screenStream == stream) {
        self.screenStream = nil;
      }
      self.screenCaptureFinishing = NO;
    }

    [stream release];
  };

  if (stopStream && stream) {
    [stream stopCaptureWithCompletionHandler:finish];
  } else {
    finish(nil);
  }
}

- (dispatch_semaphore_t)captureHDR:(FrameCallbackBlock)frameCallback {
  if (@available(macOS 15.0, *)) {
    @synchronized(self) {
      if (self.captureStopRequested) {
        return nil;
      }

      if (self.screenStream || self.screenCaptureFinishing) {
        self.captureFailed = YES;
        NSLog(@"Sunshine HDR: attempted to start a second ScreenCaptureKit stream");
        return nil;
      }

      // Build the HDR configuration explicitly. The canonical HDR preset
      // defaults to packed 4:4:4, while VideoToolbox HEVC Main10 consumes
      // P010. Request P010 at capture time to avoid an intermediate chroma
      // conversion and guarantee the format validated below.
      SCStreamConfiguration *configuration = [[[SCStreamConfiguration alloc] init] autorelease];
      configuration.captureDynamicRange = SCCaptureDynamicRangeHDRCanonicalDisplay;
      configuration.width = self.frameWidth;
      configuration.height = self.frameHeight;
      configuration.minimumFrameInterval = self.minFrameDuration;
      configuration.pixelFormat = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange;
      configuration.colorSpaceName = kCGColorSpaceITUR_2100_PQ;
      configuration.colorMatrix = kCVImageBufferYCbCrMatrix_ITU_R_2020;
      configuration.queueDepth = 3;
      configuration.scalesToFit = YES;
      configuration.preservesAspectRatio = YES;
      configuration.showsCursor = YES;
      configuration.capturesAudio = NO;
      configuration.streamName = @"Sunshine HDR display capture";

      self.captureFailed = NO;
      self.screenCaptureValidated = NO;
      self.screenCaptureFinishing = NO;
      self.screenFrameCallback = frameCallback;
      self.screenCaptureSignal = dispatch_semaphore_create(0);

      SCStream *stream = [[SCStream alloc] initWithFilter:self.screenContentFilter
                                            configuration:configuration
                                                 delegate:self];
      self.screenStream = stream;
      [stream release];

      dispatch_queue_attr_t qos =
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, DISPATCH_QUEUE_PRIORITY_HIGH);
      dispatch_queue_t captureQueue = dispatch_queue_create("sunshineScreenCaptureKitHDR", qos);
      NSError *addOutputError = nil;

      if (![self.screenStream addStreamOutput:self
                                         type:SCStreamOutputTypeScreen
                           sampleHandlerQueue:captureQueue
                                        error:&addOutputError]) {
        NSLog(@"Sunshine HDR: failed to add ScreenCaptureKit output: %@", addOutputError);
        self.captureFailed = YES;
        self.screenFrameCallback = nil;
        self.screenStream = nil;
        self.screenCaptureSignal = nil;
        return nil;
      }

      dispatch_semaphore_t signal = self.screenCaptureSignal;
      [self.screenStream startCaptureWithCompletionHandler:^(NSError *error) {
        if (error) {
          [self finishScreenCaptureStoppingStream:NO failed:YES error:error];
        }
      }];

      return signal;
    }
  }

  self.captureFailed = YES;
  return nil;
}

- (dispatch_semaphore_t)captureAVFoundation:(FrameCallbackBlock)frameCallback {
  @synchronized(self) {
    if (self.captureStopRequested) {
      return nil;
    }

    self.captureFailed = NO;
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    [videoOutput setVideoSettings:@{
      (NSString *) kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:self.pixelFormat],
      (NSString *) kCVPixelBufferWidthKey: [NSNumber numberWithInt:self.frameWidth],
      (NSString *) kCVPixelBufferHeightKey: [NSNumber numberWithInt:self.frameHeight],
      (NSString *) AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
    }];

    dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, DISPATCH_QUEUE_PRIORITY_HIGH);
    dispatch_queue_t recordingQueue = dispatch_queue_create("videoCaptureQueue", qos);
    [videoOutput setSampleBufferDelegate:self queue:recordingQueue];

    [self.session stopRunning];

    if ([self.session canAddOutput:videoOutput]) {
      [self.session addOutput:videoOutput];
    } else {
      [videoOutput release];
      return nil;
    }

    AVCaptureConnection *videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);

    [self.videoOutputs setObject:videoOutput forKey:videoConnection];
    [self.captureCallbacks setObject:frameCallback forKey:videoConnection];
    [self.captureSignals setObject:signal forKey:videoConnection];

    [self.session startRunning];

    return signal;
  }
}

- (dispatch_semaphore_t)capture:(FrameCallbackBlock)frameCallback {
  return self.hdrCaptureEnabled ? [self captureHDR:frameCallback] : [self captureAVFoundation:frameCallback];
}

- (void)stopCapture {
  @synchronized(self) {
    self.captureStopRequested = YES;
  }

  if (self.hdrCaptureEnabled) {
    [self finishScreenCaptureStoppingStream:YES failed:NO error:nil];
  }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
         fromConnection:(AVCaptureConnection *)connection {
  FrameCallbackBlock callback = [self.captureCallbacks objectForKey:connection];

  if (callback != nil) {
    if (!callback(sampleBuffer)) {
      @synchronized(self) {
        [self.session stopRunning];
        [self.captureCallbacks removeObjectForKey:connection];
        [self.session removeOutput:[self.videoOutputs objectForKey:connection]];
        [self.videoOutputs removeObjectForKey:connection];
        dispatch_semaphore_signal([self.captureSignals objectForKey:connection]);
        [self.captureSignals removeObjectForKey:connection];
        [self.session startRunning];
      }
    }
  }
}

- (void)stream:(SCStream *)stream
  didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                 ofType:(SCStreamOutputType)type {
  if (type != SCStreamOutputTypeScreen || !CMSampleBufferIsValid(sampleBuffer)) {
    return;
  }

  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (!imageBuffer) {
    return;
  }

  if (!self.screenCaptureValidated) {
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    CFTypeRef colorPrimaries = CVBufferCopyAttachment(imageBuffer, kCVImageBufferColorPrimariesKey, NULL);
    CFTypeRef transferFunction = CVBufferCopyAttachment(imageBuffer, kCVImageBufferTransferFunctionKey, NULL);
    CFTypeRef colorMatrix = CVBufferCopyAttachment(imageBuffer, kCVImageBufferYCbCrMatrixKey, NULL);

    BOOL validHDRFrame =
      pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange &&
      colorPrimaries && CFEqual(colorPrimaries, kCVImageBufferColorPrimaries_ITU_R_2020) &&
      transferFunction && CFEqual(transferFunction, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ) &&
      colorMatrix && CFEqual(colorMatrix, kCVImageBufferYCbCrMatrix_ITU_R_2020);

    if (colorPrimaries) {
      CFRelease(colorPrimaries);
    }
    if (transferFunction) {
      CFRelease(transferFunction);
    }
    if (colorMatrix) {
      CFRelease(colorMatrix);
    }

    if (!validHDRFrame) {
      NSError *error = [NSError errorWithDomain:@"dev.lizardbyte.app.Sunshine.HDRCapture"
                                           code:1
                                       userInfo:@{
                                         NSLocalizedDescriptionKey: @"ScreenCaptureKit did not return a BT.2020 PQ P010 frame",
                                       }];
      [self finishScreenCaptureStoppingStream:YES failed:YES error:error];
      return;
    }

    self.screenCaptureValidated = YES;
    NSLog(@"Sunshine HDR: validated BT.2020 PQ P010 capture at %zux%zu",
          CVPixelBufferGetWidth(imageBuffer),
          CVPixelBufferGetHeight(imageBuffer));
  }

  FrameCallbackBlock callback = nil;
  @synchronized(self) {
    callback = [self.screenFrameCallback copy];
  }

  if (!callback) {
    return;
  }

  BOOL keepCapturing = callback(sampleBuffer);
  [callback release];

  if (!keepCapturing) {
    [self finishScreenCaptureStoppingStream:YES failed:NO error:nil];
  }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
  [self finishScreenCaptureStoppingStream:NO failed:YES error:error];
}

@end
