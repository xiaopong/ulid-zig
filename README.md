# ulid-zig

Zig implementation of the [ulid][ulid] project, providing Universally Unique Lexicographically Sortable Identifiers.

[ulid]: https://github.com/ulid/spec

# Usage

See examples in main.zig for more details.

# Benchmark

Half-hearted attempt benchmarking on an old Mac laptop:

```
Model        : MacBook Pro 2018
Processor    : 2.2 GHz 6-Core Intel Core i7
Memory       : 16 GB 2400 MHz DDR4
```
Zig version:
```
Zig version  : 0.14.0-dev.296+bd7b2cc4b
Build option : --release=fast
```
Benchmark resuls:
```
Generated 100000000 ULIDs in 5.447s
Average: 54.465ns per ULID
Rate: 18.36M ULIDs/second
```
See the codes in main.zig for more information.


