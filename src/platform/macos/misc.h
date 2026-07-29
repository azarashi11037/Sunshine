/**
 * @file src/platform/macos/misc.h
 * @brief Miscellaneous declarations for macOS platform.
 */
#pragma once

// standard includes
#include <string>
#include <string_view>
#include <vector>

// platform includes
#include <CoreGraphics/CoreGraphics.h>

namespace platf {
  /**
   * Return a stable macOS display selector backed by the display UUID.
   *
   * Unlike CGDirectDisplayID, this selector survives a display disconnect and
   * reconnect within the same macOS installation.
   */
  std::string display_uuid_selector(CGDirectDisplayID display_id);

  /**
   * Resolve either a legacy numeric CGDirectDisplayID or a stable UUID selector
   * to the display's current CGDirectDisplayID.
   */
  CGDirectDisplayID display_id_from_selector(std::string_view selector, CGDirectDisplayID fallback);

  bool is_screen_capture_allowed();
}

namespace dyn {
  typedef void (*apiproc)();

  int load(void *handle, const std::vector<std::tuple<apiproc *, const char *>> &funcs, bool strict = true);
  void *handle(const std::vector<const char *> &libs);

}  // namespace dyn
