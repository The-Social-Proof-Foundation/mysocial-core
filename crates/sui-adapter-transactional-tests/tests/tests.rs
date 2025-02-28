// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

pub const TEST_DIR: &str = "tests";
// Support both sui_transactional_test_runner and mysocial_transactional_test_runner
#[allow(unused_imports)]
use sui_transactional_test_runner::run_test;

datatest_stable::harness!(run_test, TEST_DIR, r".*\.(mvir|move)$");
