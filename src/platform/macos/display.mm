/**
 * @file src/platform/macos/display.mm
 * @brief Definitions for display capture on macOS.
 */
// standard includes
#include <charconv>
#include <cstring>
#include <mutex>
#include <thread>

// platform includes
#include <IOKit/pwr_mgt/IOPMLib.h>

// local includes
#include "src/config.h"
#include "src/logging.h"
#include "src/platform/common.h"
#include "src/platform/macos/av_img_t.h"
#include "src/platform/macos/av_video.h"
#include "src/platform/macos/misc.h"
#include "src/platform/macos/nv12_zero_device.h"

// Avoid conflict between AVFoundation and libavutil both defining AVMediaType
#define AVMediaType AVMediaType_FFmpeg
#include "src/video.h"
#undef AVMediaType

namespace fs = std::filesystem;

namespace platf {
  using namespace std::literals;

  namespace {
    bool display_selector_is_active(std::string_view selector) {
      CGDirectDisplayID active_displays[kMaxDisplays] {};
      uint32_t display_count {};
      if (CGGetActiveDisplayList(kMaxDisplays, active_displays, &display_count) != kCGErrorSuccess) {
        return false;
      }

      if (selector.empty()) {
        return display_count > 0;
      }

      CGDirectDisplayID numeric_display_id {};
      const auto numeric_result = std::from_chars(
        selector.data(),
        selector.data() + selector.size(),
        numeric_display_id
      );
      const bool is_numeric_selector =
        numeric_result.ec == std::errc {} && numeric_result.ptr == selector.data() + selector.size();

      for (uint32_t index = 0; index < display_count; ++index) {
        const auto display_id = active_displays[index];
        if ((is_numeric_selector && display_id == numeric_display_id) ||
            (!is_numeric_selector && selector == display_uuid_selector(display_id))) {
          return true;
        }
      }

      return false;
    }

    void wake_display_for_capture(std::string_view selector) {
      if (display_selector_is_active(selector)) {
        return;
      }

      IOPMAssertionID wake_assertion = kIOPMNullAssertionID;
      const auto result = IOPMAssertionDeclareUserActivity(
        CFSTR("Sunshine display detection"),
        kIOPMUserActiveRemote,
        &wake_assertion
      );

      if (result != kIOReturnSuccess) {
        BOOST_LOG(warning) << "Unable to declare remote user activity to wake displays, IOReturn: "sv << result;
        return;
      }

      BOOST_LOG(info) << "Declared remote user activity to wake displays"sv;

      for (int attempt = 0; attempt < 30 && !display_selector_is_active(selector); ++attempt) {
        std::this_thread::sleep_for(100ms);
      }

      if (!display_selector_is_active(selector)) {
        BOOST_LOG(warning) << "Display wake attempt did not expose the requested display ["sv
                           << selector << "] in the active display list."sv;
      }

      if (wake_assertion != kIOPMNullAssertionID) {
        const auto release_result = IOPMAssertionRelease(wake_assertion);
        if (release_result != kIOReturnSuccess) {
          BOOST_LOG(warning) << "Unable to release display wake assertion, IOReturn: "sv << release_result;
        }
      }
    }
  }  // namespace

  struct capture_callback_context_t {
    capture_callback_context_t(
      const display_t::push_captured_image_cb_t &push_callback,
      const display_t::pull_free_image_cb_t &pull_callback
    ):
        push_callback {push_callback},
        pull_callback {pull_callback} {
    }

    std::mutex mutex;
    bool active {true};
    display_t::push_captured_image_cb_t push_callback;
    display_t::pull_free_image_cb_t pull_callback;
  };

  struct dummy_capture_context_t {
    explicit dummy_capture_context_t(img_t *image):
        image {image} {
    }

    std::mutex mutex;
    bool active {true};
    img_t *image;
  };

  struct av_display_t: public display_t {
    AVVideo *av_capture {};
    CGDirectDisplayID display_id {};
    IOPMAssertionID display_sleep_assertion {kIOPMNullAssertionID};

    ~av_display_t() override {
      [av_capture release];

      if (display_sleep_assertion != kIOPMNullAssertionID) {
        const auto result = IOPMAssertionRelease(display_sleep_assertion);
        if (result != kIOReturnSuccess) {
          BOOST_LOG(warning) << "Unable to release display sleep assertion, IOReturn: "sv << result;
        }
      }
    }

    void prevent_display_sleep() {
      if (display_sleep_assertion != kIOPMNullAssertionID) {
        return;
      }

      const auto result = IOPMAssertionCreateWithName(
        kIOPMAssertPreventUserIdleDisplaySleep,
        kIOPMAssertionLevelOn,
        CFSTR("Sunshine display capture"),
        &display_sleep_assertion
      );

      if (result == kIOReturnSuccess) {
        BOOST_LOG(debug) << "Keeping display awake for capture"sv;
        return;
      }

      display_sleep_assertion = kIOPMNullAssertionID;
      BOOST_LOG(warning) << "Unable to create display sleep prevention assertion, IOReturn: "sv << result;
    }

    void stop_capture() override {
      [av_capture stopCapture];
    }

    capture_e capture(const push_captured_image_cb_t &push_captured_image_cb, const pull_free_image_cb_t &pull_free_image_cb, bool *cursor) override {
      // ScreenCaptureKit can deliver a frame after stopCapture() has signalled
      // the waiting capture thread. Keep callback invocation serialized with
      // capture() teardown so a late frame can never call C++ closures whose
      // capture-thread stack has already been destroyed.
      auto callbacks = std::make_shared<capture_callback_context_t>(
        push_captured_image_cb,
        pull_free_image_cb
      );

      auto signal = [av_capture capture:^(CMSampleBufferRef sampleBuffer) {
        std::lock_guard<std::mutex> lock {callbacks->mutex};
        if (!callbacks->active) {
          return false;
        }

        auto new_sample_buffer = std::make_shared<av_sample_buf_t>(sampleBuffer);
        auto new_pixel_buffer = std::make_shared<av_pixel_buf_t>(new_sample_buffer->buf);

        std::shared_ptr<img_t> img_out;
        if (!callbacks->pull_callback(img_out)) {
          // got interrupt signal
          // returning false here stops capture backend
          return false;
        }
        auto av_img = std::static_pointer_cast<av_img_t>(img_out);

        auto old_data_retainer = std::make_shared<temp_retain_av_img_t>(
          av_img->sample_buffer,
          av_img->pixel_buffer,
          img_out->data
        );

        av_img->sample_buffer = new_sample_buffer;
        av_img->pixel_buffer = new_pixel_buffer;
        img_out->data = new_pixel_buffer->data();

        img_out->width = (int) CVPixelBufferGetWidth(new_pixel_buffer->buf);
        img_out->height = (int) CVPixelBufferGetHeight(new_pixel_buffer->buf);
        img_out->row_pitch = (int) CVPixelBufferGetBytesPerRow(new_pixel_buffer->buf);
        img_out->pixel_pitch = img_out->row_pitch / img_out->width;

        old_data_retainer = nullptr;

        if (!callbacks->push_callback(std::move(img_out), true)) {
          // got interrupt signal
          // returning false here stops capture backend
          return false;
        }

        return true;
      }];

      if (!signal) {
        return capture_e::error;
      }

      // FIXME: We should time out if an image isn't returned for a while
      dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);

      {
        std::lock_guard<std::mutex> lock {callbacks->mutex};
        callbacks->active = false;
        callbacks->push_callback = {};
        callbacks->pull_callback = {};
      }

      return av_capture.captureFailed ? capture_e::error : capture_e::ok;
    }

    std::shared_ptr<img_t> alloc_img() override {
      return std::make_shared<av_img_t>();
    }

    std::unique_ptr<avcodec_encode_device_t> make_avcodec_encode_device(pix_fmt_e pix_fmt) override {
      if (pix_fmt == pix_fmt_e::yuv420p) {
        av_capture.pixelFormat = kCVPixelFormatType_32BGRA;

        return std::make_unique<avcodec_encode_device_t>();
      } else if (pix_fmt == pix_fmt_e::nv12 || pix_fmt == pix_fmt_e::p010) {
        auto device = std::make_unique<nv12_zero_device>();

        device->init(static_cast<void *>(av_capture), pix_fmt, setResolution, setPixelFormat);

        return device;
      } else {
        BOOST_LOG(error) << "Unsupported Pixel Format."sv;
        return nullptr;
      }
    }

    int dummy_img(img_t *img) override {
      if (!platf::is_screen_capture_allowed()) {
        // If we don't have the screen capture permission, this function will hang
        // indefinitely without doing anything useful. Exit instead to avoid this.
        // A non-zero return value indicates failure to the calling function.
        return 1;
      }

      auto capture_context = std::make_shared<dummy_capture_context_t>(img);
      auto signal = [av_capture capture:^(CMSampleBufferRef sampleBuffer) {
        std::lock_guard<std::mutex> lock {capture_context->mutex};
        if (!capture_context->active || !capture_context->image) {
          return false;
        }

        auto new_sample_buffer = std::make_shared<av_sample_buf_t>(sampleBuffer);
        auto new_pixel_buffer = std::make_shared<av_pixel_buf_t>(new_sample_buffer->buf);

        auto image = capture_context->image;
        auto av_img = (av_img_t *) image;

        auto old_data_retainer = std::make_shared<temp_retain_av_img_t>(
          av_img->sample_buffer,
          av_img->pixel_buffer,
          image->data
        );

        av_img->sample_buffer = new_sample_buffer;
        av_img->pixel_buffer = new_pixel_buffer;
        image->data = new_pixel_buffer->data();

        image->width = (int) CVPixelBufferGetWidth(new_pixel_buffer->buf);
        image->height = (int) CVPixelBufferGetHeight(new_pixel_buffer->buf);
        image->row_pitch = (int) CVPixelBufferGetBytesPerRow(new_pixel_buffer->buf);
        image->pixel_pitch = image->row_pitch / image->width;

        old_data_retainer = nullptr;

        // returning false here stops capture backend
        return false;
      }];

      if (!signal) {
        return 1;
      }

      constexpr auto first_frame_timeout = 5s;
      const auto timeout = dispatch_time(
        DISPATCH_TIME_NOW,
        std::chrono::duration_cast<std::chrono::nanoseconds>(first_frame_timeout).count()
      );
      const bool timed_out = dispatch_semaphore_wait(signal, timeout) != 0;

      {
        std::lock_guard<std::mutex> lock {capture_context->mutex};
        capture_context->active = false;
        capture_context->image = nullptr;
      }

      if (timed_out) {
        BOOST_LOG(error) << "Timed out waiting for the first frame from macOS display capture"sv;
        [av_capture stopCapture];
        return 1;
      }

      return av_capture.captureFailed ? 1 : 0;
    }

    /**
     * A bridge from the pure C++ code of the hwdevice_t class to the pure Objective C code.
     *
     * display --> an opaque pointer to an object of this class
     * width --> the intended capture width
     * height --> the intended capture height
     */
    static void setResolution(void *display, int width, int height) {
      [static_cast<AVVideo *>(display) setFrameWidth:width frameHeight:height];
    }

    static void setPixelFormat(void *display, OSType pixelFormat) {
      static_cast<AVVideo *>(display).pixelFormat = pixelFormat;
    }

    bool is_hdr() override {
      return av_capture.isHDRCaptureEnabled;
    }

    bool get_hdr_metadata(SS_HDR_METADATA &metadata) override {
      if (!is_hdr()) {
        return false;
      }

      std::memset(&metadata, 0, sizeof(metadata));

      // ScreenCaptureKit is configured for BT.2020 primaries, D65 white,
      // and SMPTE ST 2084 PQ. Luminance values use a conservative HDR10
      // mastering envelope suitable for a remote canonical HDR display.
      metadata.displayPrimaries[0].x = 0.708f * 50000;
      metadata.displayPrimaries[0].y = 0.292f * 50000;
      metadata.displayPrimaries[1].x = 0.170f * 50000;
      metadata.displayPrimaries[1].y = 0.797f * 50000;
      metadata.displayPrimaries[2].x = 0.131f * 50000;
      metadata.displayPrimaries[2].y = 0.046f * 50000;
      metadata.whitePoint.x = 0.3127f * 50000;
      metadata.whitePoint.y = 0.3290f * 50000;
      metadata.maxDisplayLuminance = 1000;
      metadata.minDisplayLuminance = 1;
      metadata.maxContentLightLevel = 0;
      metadata.maxFrameAverageLightLevel = 0;
      metadata.maxFullFrameLuminance = 1000;

      return true;
    }
  };

  std::shared_ptr<display_t> display(platf::mem_type_e hwdevice_type, const std::string &display_name, const video::config_t &config) {
    if (hwdevice_type != platf::mem_type_e::system && hwdevice_type != platf::mem_type_e::videotoolbox) {
      BOOST_LOG(error) << "Could not initialize display with the given hw device type."sv;
      return nullptr;
    }

    auto display = std::make_shared<av_display_t>();

    // AVFoundation and ScreenCaptureKit do not deliver frames for sleeping
    // displays. Hold the display awake for this capture object's lifetime and
    // wake it before resolving the configured stable selector.
    display->prevent_display_sleep();
    wake_display_for_capture(display_name);

    // Print all displays available with it's name and id
    auto display_array = [AVVideo displayNames];
    BOOST_LOG(info) << "Detecting displays"sv;
    for (NSDictionary *item in display_array) {
      NSNumber *display_id = item[@"id"];
      // We need show display's product name and corresponding display number given by user
      NSString *name = item[@"displayName"];
      // We are using CGGetActiveDisplayList that only returns active displays so hardcoded connected value in log to true
      BOOST_LOG(info) << "Detected display: "sv << name.UTF8String << " (id: "sv << [NSString stringWithFormat:@"%@", display_id].UTF8String << ") connected: true"sv;
    }
    display->display_id = display_id_from_selector(display_name, CGMainDisplayID());
    BOOST_LOG(info) << "Configuring selected display ("sv << display->display_id << ") to stream"sv;

    const bool request_hdr_capture =
      config.dynamicRange > 0 && hwdevice_type == platf::mem_type_e::videotoolbox;
    display->av_capture = [[AVVideo alloc] initWithDisplay:display->display_id
                                                frameRate:config.framerate
                                                      hdr:request_hdr_capture];

    if (!display->av_capture) {
      BOOST_LOG(error) << "Video setup failed."sv;
      return nullptr;
    }

    if (display->av_capture.isHDRCaptureEnabled) {
      BOOST_LOG(info) << "Using ScreenCaptureKit BT.2020 PQ HDR capture"sv;
    }

    display->width = display->av_capture.frameWidth;
    display->height = display->av_capture.frameHeight;
    // We also need set env_width and env_height for absolute mouse coordinates
    display->env_width = display->width;
    display->env_height = display->height;

    return display;
  }

  std::vector<std::string> display_names(mem_type_e hwdevice_type) {
    __block std::vector<std::string> display_names;

    auto display_array = [AVVideo displayNames];
    const bool use_stable_selectors = config::video.output_name.rfind("uuid:", 0) == 0;

    display_names.reserve([display_array count]);
    [display_array enumerateObjectsUsingBlock:^(NSDictionary *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
      if (use_stable_selectors) {
        NSNumber *display_id = obj[@"id"];
        auto selector = display_uuid_selector([display_id unsignedIntValue]);
        if (!selector.empty()) {
          display_names.emplace_back(std::move(selector));
          return;
        }
      }

      NSString *legacy_name = obj[@"name"];
      display_names.emplace_back(legacy_name.UTF8String);
    }];

    return display_names;
  }

  /**
   * @brief Returns if GPUs/drivers have changed since the last call to this function.
   * @return `true` if a change has occurred or if it is unknown whether a change occurred.
   */
  bool needs_encoder_reenumeration() {
    // We don't track GPU state, so we will always reenumerate. Fortunately, it is fast on macOS.
    return true;
  }
}  // namespace platf
