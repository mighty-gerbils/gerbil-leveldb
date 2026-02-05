# Gerbil LevelDB Driver

This package provides a Gerbil LevelDB driver using `libleveldb`.

## Dependencies

You need to have `libleveldb` installed in your system.

### Ubuntu:

```
$ sudo apt install libleveldb-dev
```

### macOS:

Install [homebrew](https://brew.sh) (if not already done):

```
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

then install leveldb:

```
$ brew install leveldb
```

#### macOS on ARM:
On ARM64 architectures (M1...) Homebrew installs its bits in `/opt/homebrew`. For some reason `leveldb` does not provide support for `pkg-config`. macOS users on ARM need to export `CPPFLAGS` and `LDFLAGS` for the compiler to find leveldb headers and library.

```
$ arch          ## arm64 
$ export CPPFLAGS=-I/opt/homebrew/include
$ export LDFLAGS=-L/opt/homebrew/lib
```

## Installation

To install the package in your `$GERBIL_PATH` (`~/.gerbil` by default):

```shell
$ gerbil pkg install github.com/mighty-gerbils/gerbil-leveldb
```

## Building and Testing

Build the library:
```shell
$ ./build.ss
# or
$ make build
```

Run tests:
```shell
$ make test
```

The functional test (`test/functional-test.ss`) exercises all features including:
- Version query
- Options with all parameters (including `max-file-size:` and `env:`)
- Environment creation
- Basic put/get/delete operations
- Write batches and batch append
- Snapshots with point-in-time reads
- Iterators and `in-leveldb` iteration
- Database properties
- Approximate size queries
- Compaction, repair, and destroy

## API

To use bindings from this package:
```scheme
(import :clan/db/leveldb)
```

## Quick Start

```scheme
(import :clan/db/leveldb)

;; Open a database (creates if it doesn't exist)
(def db (leveldb-open "/path/to/mydb"))

;; Put a key-value pair
(leveldb-put db "mykey" "myvalue")

;; Get a value (returns u8vector or #f if not found)
(def val (leveldb-get db "mykey"))
(when val (displayln (bytes->string val)))

;; Delete a key
(leveldb-delete db "mykey")

;; Close the database
(leveldb-close db)
```

## Database Operations

### leveldb-open

```scheme
(leveldb-open name [opts]) -> leveldb
```

Opens a LevelDB database at the specified path. Creates the database if it doesn't exist (by default).

- `name`: Path to the database directory (string)
- `opts`: Optional options object created with `leveldb-options`

### leveldb-close

```scheme
(leveldb-close db) -> void
```

Closes the database and releases resources.

### leveldb-put

```scheme
(leveldb-put db key val [opts]) -> void
```

Stores a key-value pair in the database.

- `key`: Key as string or u8vector
- `val`: Value as string or u8vector
- `opts`: Optional write options

### leveldb-get

```scheme
(leveldb-get db key [opts]) -> u8vector | #f
```

Retrieves a value by key. Returns `#f` if the key doesn't exist.

### leveldb-delete

```scheme
(leveldb-delete db key [opts]) -> void
```

Deletes a key from the database.

### leveldb-key?

```scheme
(leveldb-key? db key [opts]) -> boolean
```

Checks if a key exists in the database.

## Write Batches

Write batches allow atomic updates of multiple keys.

### leveldb-writebatch

```scheme
(leveldb-writebatch) -> writebatch
```

Creates a new write batch.

### leveldb-writebatch-put

```scheme
(leveldb-writebatch-put batch key val) -> void
```

Adds a put operation to the batch.

### leveldb-writebatch-delete

```scheme
(leveldb-writebatch-delete batch key) -> void
```

Adds a delete operation to the batch.

### leveldb-writebatch-append

```scheme
(leveldb-writebatch-append dest src) -> void
```

Appends all operations from `src` batch to `dest` batch. Useful for composing batches.

```scheme
(def wb1 (leveldb-writebatch))
(def wb2 (leveldb-writebatch))
(leveldb-writebatch-put wb1 "a" "1")
(leveldb-writebatch-put wb2 "b" "2")
(leveldb-writebatch-append wb1 wb2)  ;; wb1 now has both operations
(leveldb-write db wb1)
```

### leveldb-writebatch-clear

```scheme
(leveldb-writebatch-clear batch) -> void
```

Clears all operations from a write batch.

### leveldb-write

```scheme
(leveldb-write db batch [opts]) -> void
```

Atomically applies all operations in the batch to the database.

## Snapshots

Snapshots provide a consistent read-only view of the database at a point in time.

### leveldb-snapshot

```scheme
(leveldb-snapshot db) -> snapshot
```

Creates a snapshot of the current database state.

### leveldb-snapshot-release

```scheme
(leveldb-snapshot-release db snapshot) -> void
```

Releases a snapshot when no longer needed.

### Example

```scheme
;; Create snapshot
(leveldb-put db "key" "value1")
(def snap (leveldb-snapshot db))

;; Modify after snapshot
(leveldb-put db "key" "value2")

;; Read current value
(leveldb-get db "key")  ;; => "value2"

;; Read from snapshot
(def snap-opts (leveldb-read-options snapshot: snap))
(leveldb-get db "key" snap-opts)  ;; => "value1"

;; Release when done
(leveldb-snapshot-release db snap)
```

## Iterators

Iterators allow sequential scanning of key-value pairs.

### leveldb-iterator

```scheme
(leveldb-iterator db [opts]) -> iterator
```

Creates an iterator for the database.

### leveldb-iterator-close

```scheme
(leveldb-iterator-close iter) -> void
```

Closes the iterator.

### leveldb-iterator-valid?

```scheme
(leveldb-iterator-valid? iter) -> boolean
```

Returns `#t` if the iterator is positioned at a valid entry.

### leveldb-iterator-seek-first / leveldb-iterator-seek-last

```scheme
(leveldb-iterator-seek-first iter) -> void
(leveldb-iterator-seek-last iter) -> void
```

Positions the iterator at the first or last entry.

### leveldb-iterator-seek

```scheme
(leveldb-iterator-seek iter key) -> void
```

Positions the iterator at the first entry with key >= `key`.

### leveldb-iterator-next / leveldb-iterator-prev

```scheme
(leveldb-iterator-next iter) -> void
(leveldb-iterator-prev iter) -> void
```

Moves to the next or previous entry.

### leveldb-iterator-key / leveldb-iterator-value

```scheme
(leveldb-iterator-key iter) -> u8vector
(leveldb-iterator-value iter) -> u8vector
```

Returns the key or value at the current position.

### in-leveldb / in-leveldb-keys

```scheme
(in-leveldb db [start] [limit]) -> iterator
(in-leveldb-keys db [start] [limit]) -> iterator
```

Creates iterators compatible with Gerbil's `for` loops.

```scheme
;; Iterate over all key-value pairs
(for ((values key val) (in-leveldb db))
  (displayln (bytes->string key) " = " (bytes->string val)))

;; Iterate over keys only
(for (key (in-leveldb-keys db))
  (displayln (bytes->string key)))

;; With range
(for ((values key val) (in-leveldb db "a" "z"))
  ...)
```

## Database Properties

### leveldb-property

```scheme
(leveldb-property db name) -> string | #f
```

Returns a database property value. Available properties include:

- `"leveldb.stats"` - Multi-line statistics
- `"leveldb.sstables"` - SSTable information
- `"leveldb.approximate-memory-usage"` - Memory usage estimate

```scheme
(displayln (leveldb-property db "leveldb.stats"))
```

### leveldb-approximate-size

```scheme
(leveldb-approximate-size db start-key end-key) -> integer
```

Returns the approximate size in bytes of the data in the given key range.

```scheme
(leveldb-approximate-size db "a" "z")  ;; size of keys from "a" to "z"
```

## Database Maintenance

### leveldb-compact-range

```scheme
(leveldb-compact-range db start-key end-key) -> void
```

Compacts the underlying storage for the given key range.

### leveldb-destroy-db

```scheme
(leveldb-destroy-db name [opts]) -> void
```

Destroys (deletes) a database and all its files.

### leveldb-repair-db

```scheme
(leveldb-repair-db name [opts]) -> void
```

Attempts to repair a corrupted database.

## Options

### leveldb-options

```scheme
(leveldb-options keyword-args ...) -> options
```

Creates database options. Keyword arguments:

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `create-if-missing:` | boolean | `#t` | Create database if it doesn't exist |
| `error-if-exists:` | boolean | `#f` | Error if database already exists |
| `paranoid-checks:` | boolean | `#f` | Enable paranoid consistency checks |
| `compression:` | boolean | `#t` | Enable Snappy compression |
| `write-buffer-size:` | integer | — | Write buffer size in bytes |
| `max-open-files:` | integer | — | Maximum number of open files |
| `block-size:` | integer | — | Block size in bytes |
| `block-restart-interval:` | integer | — | Block restart interval |
| `max-file-size:` | integer | — | Maximum file size in bytes |
| `lru-cache-capacity:` | integer | — | LRU cache size in bytes |
| `bloom-filter-bits:` | integer | — | Bloom filter bits per key |
| `env:` | env | — | Custom environment (for testing) |

```scheme
(def opts (leveldb-options
            write-buffer-size: 67108864    ;; 64MB
            max-open-files: 1000
            bloom-filter-bits: 10
            max-file-size: 2097152))       ;; 2MB
(def db (leveldb-open "/path/to/db" opts))
```

### leveldb-default-options

```scheme
(leveldb-default-options) -> options
```

Returns the default options (cached, reusable).

### leveldb-read-options

```scheme
(leveldb-read-options keyword-args ...) -> read-options
```

Creates read options. Keyword arguments:

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `verify-checksums:` | boolean | `#f` | Verify checksums on read |
| `fill-cache:` | boolean | `#f` | Fill cache on read |
| `snapshot:` | snapshot | — | Read from a snapshot |

### leveldb-write-options

```scheme
(leveldb-write-options keyword-args ...) -> write-options
```

Creates write options. Keyword arguments:

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `sync:` | boolean | `#f` | Sync writes to disk |

## Environment

### leveldb-default-env

```scheme
(leveldb-default-env) -> env
```

Returns the default environment. Can be passed to `leveldb-options` with `env:`.

### leveldb-env-test-directory

```scheme
(leveldb-env-test-directory env) -> string
```

Returns a path to a temporary test directory.

## Version

### leveldb-version

```scheme
(leveldb-version) -> (values major minor)
```

Returns the LevelDB library version as two values.

```scheme
(defvalues (major minor) (leveldb-version))
(displayln "LevelDB " major "." minor)  ;; e.g., "LevelDB 1.23"
```

## Error Handling

All operations may raise `LevelDBError` on failure.

### leveldb-error?

```scheme
(leveldb-error? obj) -> boolean
```

Predicate for LevelDB errors.

```scheme
(with-catch
  (lambda (e)
    (when (leveldb-error? e)
      (displayln "LevelDB error: " (error-message e))))
  (lambda ()
    (leveldb-open "/nonexistent/path")))
```

## Not Implemented

The following LevelDB C API features are not exposed due to FFI callback complexity:

- Custom comparators (`leveldb_comparator_create`)
- Custom filter policies (`leveldb_filterpolicy_create`)
- Write batch iteration (`leveldb_writebatch_iterate`)
- Custom environments and loggers

For custom key ordering, design your keys to sort correctly with the default byte-ordering comparator (e.g., use zero-padded numbers).

# License and Copyright

© 2017-2023 The Gerbil Core Team and contributors; License: LGPLv2.1 and Apache 2.0

Originally written by vyzo.
