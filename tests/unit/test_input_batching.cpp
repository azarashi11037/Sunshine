/**
 * @file tests/unit/test_input_batching.cpp
 * @brief Tests for input delta batching.
 */
#include "../tests_common.h"

#include <limits>

#include <src/input.h>

TEST(InputBatchingTest, AddsRepresentableDeltas) {
  std::int16_t result = 0;

  EXPECT_TRUE(input::detail::try_add_input_delta(120, 80, result));
  EXPECT_EQ(result, 200);

  EXPECT_TRUE(input::detail::try_add_input_delta(-120, 40, result));
  EXPECT_EQ(result, -80);
}

TEST(InputBatchingTest, RejectsPositiveOverflow) {
  std::int16_t result = 0;

  EXPECT_FALSE(input::detail::try_add_input_delta(std::numeric_limits<std::int16_t>::max(), 1, result));
}

TEST(InputBatchingTest, RejectsNegativeOverflow) {
  std::int16_t result = 0;

  EXPECT_FALSE(input::detail::try_add_input_delta(std::numeric_limits<std::int16_t>::min(), -1, result));
}
