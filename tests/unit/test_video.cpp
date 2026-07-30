/**
 * @file tests/unit/test_video.cpp
 * @brief Test src/video.*.
 */
#include "../tests_common.h"

#include <src/video.h>

using namespace std::chrono_literals;

namespace {
  struct async_queue_test_state_t {
    std::size_t min_pending_frames {2};
    std::size_t pending_frame_limit {2};
    std::size_t max_pending_frames {8};
    std::optional<std::chrono::steady_clock::time_point> saturated_since;
    std::optional<std::chrono::steady_clock::time_point> headroom_since;
    std::chrono::steady_clock::duration expand_after {20ms};
    std::chrono::steady_clock::duration contract_after {1s};
    std::chrono::steady_clock::duration timeout {500ms};

    video::detail::async_queue_action_e decide(
      std::size_t pending_frames,
      std::chrono::steady_clock::time_point now
    ) {
      return video::detail::async_queue_action(
        pending_frames,
        min_pending_frames,
        pending_frame_limit,
        max_pending_frames,
        saturated_since,
        headroom_since,
        now,
        expand_after,
        contract_after,
        timeout
      );
    }
  };
}  // namespace

TEST(AsyncQueueBackpressureTest, AllowsUnlimitedOrAvailableQueue) {
  async_queue_test_state_t state;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  state.min_pending_frames = 0;
  state.pending_frame_limit = 0;
  state.max_pending_frames = 0;
  EXPECT_EQ(state.decide(100, now), video::detail::async_queue_action_e::submit);

  state = {};
  EXPECT_EQ(state.decide(1, now), video::detail::async_queue_action_e::submit);
  EXPECT_FALSE(state.saturated_since.has_value());
  EXPECT_FALSE(state.headroom_since.has_value());
}

TEST(AsyncQueueBackpressureTest, ExpandsGraduallyAfterPressureGrace) {
  async_queue_test_state_t state;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(state.decide(2, now), video::detail::async_queue_action_e::retry);
  EXPECT_EQ(state.pending_frame_limit, 2);
  ASSERT_TRUE(state.saturated_since.has_value());
  EXPECT_EQ(state.decide(2, now + 19ms), video::detail::async_queue_action_e::retry);
  EXPECT_EQ(state.decide(2, now + 20ms), video::detail::async_queue_action_e::expand);
  EXPECT_EQ(state.pending_frame_limit, 3);
  EXPECT_FALSE(state.saturated_since.has_value());
}

TEST(AsyncQueueBackpressureTest, ContractsOneFrameAfterStableHeadroom) {
  async_queue_test_state_t state;
  state.pending_frame_limit = 5;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(state.decide(4, now), video::detail::async_queue_action_e::submit);
  ASSERT_TRUE(state.headroom_since.has_value());
  EXPECT_EQ(state.decide(4, now + 999ms), video::detail::async_queue_action_e::submit);
  EXPECT_EQ(state.decide(4, now + 1s), video::detail::async_queue_action_e::contract);
  EXPECT_EQ(state.pending_frame_limit, 4);
  EXPECT_FALSE(state.saturated_since.has_value());
}

TEST(AsyncQueueBackpressureTest, NeverContractsBelowMinimum) {
  async_queue_test_state_t state;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(state.decide(1, now), video::detail::async_queue_action_e::submit);
  EXPECT_EQ(state.decide(1, now + 5s), video::detail::async_queue_action_e::submit);
  EXPECT_EQ(state.pending_frame_limit, 2);
  EXPECT_FALSE(state.headroom_since.has_value());
}

TEST(AsyncQueueBackpressureTest, TimesOutOnlyAtMaximumAfterSustainedStall) {
  async_queue_test_state_t state;
  state.pending_frame_limit = 8;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(state.decide(8, now), video::detail::async_queue_action_e::retry);
  ASSERT_TRUE(state.saturated_since.has_value());
  EXPECT_EQ(*state.saturated_since, now);
  EXPECT_EQ(state.decide(8, now + 499ms), video::detail::async_queue_action_e::retry);
  EXPECT_EQ(state.decide(8, now + 500ms), video::detail::async_queue_action_e::timeout);
}

TEST(AsyncQueueBackpressureTest, ProgressResetsPressureAndContractionWindows) {
  async_queue_test_state_t state;
  state.pending_frame_limit = 5;
  const auto now = std::chrono::steady_clock::time_point {} + 1s;

  EXPECT_EQ(state.decide(5, now), video::detail::async_queue_action_e::retry);
  EXPECT_EQ(state.decide(4, now + 10ms), video::detail::async_queue_action_e::submit);
  EXPECT_FALSE(state.saturated_since.has_value());
  ASSERT_TRUE(state.headroom_since.has_value());
  EXPECT_EQ(state.decide(5, now + 100ms), video::detail::async_queue_action_e::retry);
  EXPECT_FALSE(state.headroom_since.has_value());
  EXPECT_EQ(*state.saturated_since, now + 100ms);
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
