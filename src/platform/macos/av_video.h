/**
 * @file src/platform/macos/av_video.h
 * @brief Declarations for video capture on macOS.
 */
#pragma once

// platform includes
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

struct CaptureSession {
  AVCaptureVideoDataOutput *output;
  NSCondition *captureStopped;
};

static const int kMaxDisplays = 32;

@interface AVVideo: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, SCStreamOutput, SCStreamDelegate>

@property (nonatomic, assign) CGDirectDisplayID displayID;
@property (nonatomic, assign) CMTime minFrameDuration;
@property (nonatomic, assign) OSType pixelFormat;
@property (nonatomic, assign) int frameWidth;
@property (nonatomic, assign) int frameHeight;
@property (nonatomic, assign, getter=isHDRCaptureEnabled) BOOL hdrCaptureEnabled;

typedef bool (^FrameCallbackBlock)(CMSampleBufferRef);

@property (nonatomic, assign) AVCaptureSession *session;
@property (nonatomic, assign) NSMapTable<AVCaptureConnection *, AVCaptureVideoDataOutput *> *videoOutputs;
@property (nonatomic, assign) NSMapTable<AVCaptureConnection *, FrameCallbackBlock> *captureCallbacks;
@property (nonatomic, assign) NSMapTable<AVCaptureConnection *, dispatch_semaphore_t> *captureSignals;

@property (nonatomic, retain) SCContentFilter *screenContentFilter;
@property (nonatomic, retain) SCStream *screenStream;
@property (nonatomic, copy) FrameCallbackBlock screenFrameCallback;
@property (nonatomic, assign) dispatch_semaphore_t screenCaptureSignal;
@property (nonatomic, assign) BOOL screenCaptureFinishing;
@property (nonatomic, assign) BOOL screenCaptureValidated;
@property (nonatomic, assign) BOOL captureStopRequested;
@property (nonatomic, assign) BOOL captureFailed;

+ (NSArray<NSDictionary *> *)displayNames;
+ (NSString *)getDisplayName:(CGDirectDisplayID)displayID;

- (id)initWithDisplay:(CGDirectDisplayID)displayID frameRate:(int)frameRate hdr:(BOOL)hdr;

- (void)setFrameWidth:(int)frameWidth frameHeight:(int)frameHeight;
- (dispatch_semaphore_t)capture:(FrameCallbackBlock)frameCallback;
- (void)stopCapture;

@end
