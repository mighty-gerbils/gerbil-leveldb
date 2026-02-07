;;; -*- Gerbil -*-
;;; (C) vyzo at hackzen.org
;;; :std/db/leveldb unit-test
(import :std/test
        :std/os/temporaries
        :std/values
        ./leveldb)

(export leveldb-test test-setup! test-cleanup!)

(def db #f)
(def (test-setup!)
  (let (tmp (make-temporary-file-name "test.db"))
    (set! db (leveldb-open tmp))))
(def (test-cleanup!)
  (leveldb-close db))

(def leveldb-test
  (test-suite "test :std/db/leveldb library"
    (test-case "test put/get/delete"
      (leveldb-put db "abc" "this-is-abc")
      (leveldb-put db "def" "this-is-def")
      (check (bytes->string (leveldb-get db "abc")) => "this-is-abc")
      (check (bytes->string (leveldb-get db "def")) => "this-is-def")
      (leveldb-delete db "abc")
      (check (leveldb-get db "abc") => #f)
      (leveldb-delete db "def")
      (check (leveldb-get db "def") => #f))

    (test-case "test write batch"
      (def wb (leveldb-writebatch))
      (leveldb-writebatch-put wb "abc" "this-is-abc")
      (leveldb-writebatch-put wb "def" "this-is-def")
      (leveldb-write db wb)
      (check (bytes->string (leveldb-get db "abc")) => "this-is-abc")
      (check (bytes->string (leveldb-get db "def")) => "this-is-def"))

    (test-case "test iterators"
      (def itor (leveldb-iterator db))
      (check (leveldb-iterator-valid? itor) => #f)
      (leveldb-iterator-seek-first itor)
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "abc")
      (check (bytes->string (leveldb-iterator-value itor)) => "this-is-abc")
      (leveldb-iterator-next itor)
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "def")
      (check (bytes->string (leveldb-iterator-value itor)) => "this-is-def")
      (leveldb-iterator-next itor)
      (check (leveldb-iterator-valid? itor) => #f)
      (leveldb-iterator-close itor))

    (test-case "test version"
      (defvalues (major minor) (leveldb-version))
      (check (fixnum? major) => #t)
      (check (fixnum? minor) => #t)
      (check (>= major 1) => #t))

    (test-case "test snapshots"
      ;; Write initial value
      (leveldb-put db "snap-key" "original-value")
      ;; Create snapshot
      (def snap (leveldb-snapshot db))
      (check (not (not snap)) => #t)  ;; snapshot is truthy
      ;; Modify the value after snapshot
      (leveldb-put db "snap-key" "modified-value")
      ;; Read current value (should be modified)
      (check (bytes->string (leveldb-get db "snap-key")) => "modified-value")
      ;; Read via snapshot (should be original)
      (def snap-opts (leveldb-read-options snapshot: snap))
      (check (bytes->string (leveldb-get db "snap-key" snap-opts)) => "original-value")
      ;; Release snapshot
      (leveldb-snapshot-release db snap)
      ;; Clean up
      (leveldb-delete db "snap-key"))

    (test-case "test property"
      (def stats (leveldb-property db "leveldb.stats"))
      (check (not (not stats)) => #t)  ;; stats is truthy
      ;; Invalid property should return #f
      (check (leveldb-property db "invalid.property") => #f))

    (test-case "test approximate-size"
      ;; Add some data
      (leveldb-put db "size-a" "value-a")
      (leveldb-put db "size-b" "value-b")
      (leveldb-put db "size-c" "value-c")
      ;; Get approximate size (may be 0 for small data before compaction)
      (def size (leveldb-approximate-size db "size-" "size-~"))
      (check (>= size 0) => #t)
      ;; Clean up
      (leveldb-delete db "size-a")
      (leveldb-delete db "size-b")
      (leveldb-delete db "size-c"))

    (test-case "test writebatch-append"
      (def wb1 (leveldb-writebatch))
      (def wb2 (leveldb-writebatch))
      (leveldb-writebatch-put wb1 "batch1-key" "batch1-value")
      (leveldb-writebatch-put wb2 "batch2-key" "batch2-value")
      ;; Append wb2 to wb1
      (leveldb-writebatch-append wb1 wb2)
      ;; Write wb1 (should contain both operations)
      (leveldb-write db wb1)
      (check (bytes->string (leveldb-get db "batch1-key")) => "batch1-value")
      (check (bytes->string (leveldb-get db "batch2-key")) => "batch2-value")
      ;; Clean up
      (leveldb-delete db "batch1-key")
      (leveldb-delete db "batch2-key"))

    (test-case "test options with max-file-size"
      (def opts (leveldb-options max-file-size: 4194304))  ;; 4MB
      (check (not (not opts)) => #t))  ;; opts is truthy

    (test-case "test environment"
      (def env (leveldb-default-env))
      (check (not (not env)) => #t)  ;; env is truthy
      (def test-dir (leveldb-env-test-directory env))
      (check (not (not test-dir)) => #t))  ;; test-dir is truthy

    (test-case "test options with env"
      (def env (leveldb-default-env))
      (def opts (leveldb-options env: env))
      (check (not (not opts)) => #t))))
