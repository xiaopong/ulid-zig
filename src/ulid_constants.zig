//
// Copyright (C) 2025 Xiaopong Tran
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
pub const ULID_STRING_LENGTH = 26;
pub const TIMESTAMP_LENGTH = 6; // 48 bits
pub const RANDOM_LENGTH = 10; // 80 bits
pub const TOTAL_BYTES = TIMESTAMP_LENGTH + RANDOM_LENGTH;
