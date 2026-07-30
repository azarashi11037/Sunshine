/**
 * @file tests/unit/test_video.cpp
 * @brief Test src/video.*.
 */
#include "../tests_common.h"

#include <src/video.h>

using namespace std::chrono_literals;

TEST(AsyncQueueBackpressureTest, AllowsUnlimitedOrAvailableQueue) {
  std::optional<std::chrono::steady_clock::time_point> saturated_since;
  std::size_t pending_frame_limit = 0;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(
    video::detail::async_queue_action(100, pending_frame_limit, 0, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::submit
  );
  pending_frame_limit = 4;
  EXPECT_EQ(
    video::detail::async_queue_action(3, pending_frame_limit, 8, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::submit
  );
  EXPECT_FALSE(saturated_since.has_value());
}

TEST(AsyncQueueBackpressureTest, ExpandsWithinBoundBeforeRetrying) {
  std::optional<std::chrono::steady_clock::time_point> saturated_since;
  std::size_t pending_frame_limit = 4;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(
    video::detail::async_queue_action(4, pending_frame_limit, 8, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::expand
  );
  EXPECT_EQ(pending_frame_limit, 8);
  EXPECT_FALSE(saturated_since.has_value());
}

TEST(AsyncQueueBackpressureTest, RetriesWithoutBlockingWhenFull) {
  std::optional<std::chrono::steady_clock::time_point> saturated_since;
  std::size_t pending_frame_limit = 8;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::retry
  );
  ASSERT_TRUE(saturated_since.has_value());
  EXPECT_EQ(*saturated_since, now);
  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now + 499ms, 500ms),
    video::detail::async_queue_action_e::retry
  );
}

TEST(AsyncQueueBackpressureTest, TimesOutOnlyAfterSustainedStall) {
  std::optional<std::chrono::steady_clock::time_point> saturated_since;
  std::size_t pending_frame_limit = 8;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::retry
  );
  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now + 500ms, 500ms),
    video::detail::async_queue_action_e::timeout
  );
}

TEST(AsyncQueueBackpressureTest, ProgressResetsStallWindow) {
  std::optional<std::chrono::steady_clock::time_point> saturated_since;
  std::size_t pending_frame_limit = 8;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now, 500ms),
    video::detail::async_queue_action_e::retry
  );
  EXPECT_EQ(
    video::detail::async_queue_action(7, pending_frame_limit, 8, saturated_since, now + 400ms, 500ms),
    video::detail::async_queue_action_e::submit
  );
  EXPECT_FALSE(saturated_since.has_value());
  EXPECT_EQ(
    video::detail::async_queue_action(8, pending_frame_limit, 8, saturated_since, now + 600ms, 500ms),
    video::detail::async_queue_action_e::retry
  );
  EXPECT_EQ(*saturated_since, now + 600ms);
}

struct EncoderTest: PlatformTestSuite, testing::WithParamInterface<video::encoder_t *> {
  void SetUp() override {
    auto &encoder = *GetParam();
    if (!video::validate_encoder(encoder, false)) {
      // Encoder failed validation,
      // if it's software - fail, otherwise skip
      if (encoder.name == "software") {
        FAIL() << "Software encoder not available";
      } else {
        GTEST_SKIP() << "Encoder not available";
      }
    }
  }
};

INSTANTIATE_TEST_SUITE_P(
  EncoderVariants,
  EncoderTest,
  testing::Values(
#if !defined(__APPLE__)
    &video::nvenc,
#endif
#ifdef _WIN32
    &video::amdvce,
    &video::quicksync,
#endif
#if defined(__linux__) || defined(__FreeBSD__)
    &video::vaapi,
#endif
#ifdef __APPLE__
    &video::videotoolbox,
#endif
    &video::software
  ),
  [](const auto &info) {
    return std::string(info.param->name);
  }
);

TEST_P(EncoderTest, ValidateEncoder) {
  // todo:: test something besides fixture setup
}

struct FramerateX100Test: testing::TestWithParam<std::tuple<std::int32_t, AVRational>> {};

TEST_P(FramerateX100Test, Run) {
  const auto &[x100, expected] = GetParam();
  auto res = video::framerateX100_to_rational(x100);
  ASSERT_EQ(0, av_cmp_q(res, expected)) << "expected "
                                        << expected.num << "/" << expected.den
                                        << ", got "
                                        << res.num << "/" << res.den;
}

INSTANTIATE_TEST_SUITE_P(
  FramerateX100Tests,
  FramerateX100Test,
  testing::Values(
    std::make_tuple(2397, AVRational {24000, 1001}),
    std::make_tuple(2398, AVRational {24000, 1001}),
    std::make_tuple(2500, AVRational {25, 1}),
    std::make_tuple(2997, AVRational {30000, 1001}),
    std::make_tuple(3000, AVRational {30, 1}),
    std::make_tuple(5994, AVRational {60000, 1001}),
    std::make_tuple(6000, AVRational {60, 1}),
    std::make_tuple(11988, AVRational {120000, 1001}),
    std::make_tuple(23976, AVRational {240000, 1001}),  // future NTSC 240hz?
    std::make_tuple(9498, AVRational {4749, 50})  // from my LG 27GN950
  )
);
