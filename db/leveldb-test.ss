;;; -*- Gerbil -*-
;;; (C) vyzo at hackzen.org
;;; :std/db/leveldb unit-test
(import :std/test
        :std/os/temporaries
        :std/values
        :std/iter
        :std/sort
        :clan/db/leveldb)

(export leveldb-test test-setup! test-cleanup!)

(def db #f)
(def (test-setup!)
  (let (tmp (make-temporary-file-name "test.db"))
    (set! db (leveldb-open tmp))))
(def (test-cleanup!)
  (when db
    (leveldb-close db)
    (set! db #f)))

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
      (check (not (not opts)) => #t))

    (test-case "test leveldb? predicate"
      (check (leveldb? db) => #t)
      (check (leveldb? "not-a-db") => #f)
      (check (leveldb? #f) => #f)
      (check (leveldb? 42) => #f))

    (test-case "test leveldb-error?"
      ;; leveldb-error? is a predicate for LevelDBError exceptions
      (check (leveldb-error? "not-an-error") => #f)
      (check (leveldb-error? #f) => #f))

    (test-case "test leveldb-key?"
      (leveldb-put db "exists-key" "value")
      (check (leveldb-key? db "exists-key") => #t)
      (check (leveldb-key? db "no-such-key") => #f)
      ;; Clean up
      (leveldb-delete db "exists-key"))

    (test-case "test writebatch-delete"
      (leveldb-put db "del-a" "val-a")
      (leveldb-put db "del-b" "val-b")
      (def wb (leveldb-writebatch))
      (leveldb-writebatch-delete wb "del-a")
      (leveldb-write db wb)
      (check (leveldb-get db "del-a") => #f)
      (check (bytes->string (leveldb-get db "del-b")) => "val-b")
      ;; Clean up
      (leveldb-delete db "del-b"))

    (test-case "test writebatch-clear"
      (def wb (leveldb-writebatch))
      (leveldb-writebatch-put wb "clear-a" "val-a")
      (leveldb-writebatch-put wb "clear-b" "val-b")
      ;; Clear should discard all pending operations
      (leveldb-writebatch-clear wb)
      ;; Put something new after clear
      (leveldb-writebatch-put wb "clear-c" "val-c")
      (leveldb-write db wb)
      ;; Only clear-c should exist
      (check (leveldb-get db "clear-a") => #f)
      (check (leveldb-get db "clear-b") => #f)
      (check (bytes->string (leveldb-get db "clear-c")) => "val-c")
      ;; Clean up
      (leveldb-delete db "clear-c"))

    (test-case "test iterator-seek"
      ;; Insert ordered keys
      (leveldb-put db "seek-a" "val-a")
      (leveldb-put db "seek-b" "val-b")
      (leveldb-put db "seek-c" "val-c")
      (def itor (leveldb-iterator db))
      ;; Seek to "seek-b"
      (leveldb-iterator-seek itor "seek-b")
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "seek-b")
      (check (bytes->string (leveldb-iterator-value itor)) => "val-b")
      ;; Seek past all keys
      (leveldb-iterator-seek itor "seek-z")
      (check (leveldb-iterator-valid? itor) => #f)
      (leveldb-iterator-close itor)
      ;; Clean up
      (leveldb-delete db "seek-a")
      (leveldb-delete db "seek-b")
      (leveldb-delete db "seek-c"))

    (test-case "test iterator-seek-last and prev"
      ;; Insert ordered keys
      (leveldb-put db "rev-a" "val-a")
      (leveldb-put db "rev-b" "val-b")
      (leveldb-put db "rev-c" "val-c")
      (def itor (leveldb-iterator db))
      ;; Seek to last key in DB — may not be "rev-c" if other keys exist
      (leveldb-iterator-seek-last itor)
      (check (leveldb-iterator-valid? itor) => #t)
      ;; Seek to "rev-c" specifically, then walk backwards through rev- keys
      (leveldb-iterator-seek itor "rev-c")
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "rev-c")
      ;; Move backwards
      (leveldb-iterator-prev itor)
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "rev-b")
      (leveldb-iterator-prev itor)
      (check (leveldb-iterator-valid? itor) => #t)
      (check (bytes->string (leveldb-iterator-key itor)) => "rev-a")
      (leveldb-iterator-close itor)
      ;; Clean up
      (leveldb-delete db "rev-a")
      (leveldb-delete db "rev-b")
      (leveldb-delete db "rev-c"))

    (test-case "test iterator-error"
      ;; After normal iteration, error should be #f
      (leveldb-put db "err-key" "err-val")
      (def itor (leveldb-iterator db))
      (leveldb-iterator-seek-first itor)
      (check (leveldb-iterator-error itor #f) => #f)
      (leveldb-iterator-close itor)
      ;; Clean up
      (leveldb-delete db "err-key"))

    (test-case "test in-leveldb"
      ;; Insert keys with a known prefix
      (leveldb-put db "iter-a" "val-a")
      (leveldb-put db "iter-b" "val-b")
      (leveldb-put db "iter-c" "val-c")
      ;; Iterate over the range we inserted
      (def all-pairs '())
      (for ((values k v) (in-leveldb db "iter-a" "iter-d"))
        (set! all-pairs (cons (cons (bytes->string k) (bytes->string v)) all-pairs)))
      (check (length all-pairs) => 3)
      (check (assoc "iter-b" (reverse all-pairs)) => '("iter-b" . "val-b"))
      ;; Clean up
      (leveldb-delete db "iter-a")
      (leveldb-delete db "iter-b")
      (leveldb-delete db "iter-c"))

    (test-case "test in-leveldb with start/limit range"
      ;; Insert ordered keys
      (leveldb-put db "range-a" "val-a")
      (leveldb-put db "range-b" "val-b")
      (leveldb-put db "range-c" "val-c")
      (leveldb-put db "range-d" "val-d")
      ;; Iterate from "range-b" to "range-d" (exclusive upper bound)
      (def range-keys '())
      (for ((values k v) (in-leveldb db "range-b" "range-d"))
        (set! range-keys (cons (bytes->string k) range-keys)))
      (check (sort range-keys string<?) => '("range-b" "range-c"))
      ;; Iterate with only start (no limit) — use "range-d~" as implicit end
      (def from-c '())
      (for ((values k v) (in-leveldb db "range-c" "range-e"))
        (set! from-c (cons (bytes->string k) from-c)))
      (check (sort from-c string<?) => '("range-c" "range-d"))
      ;; Clean up
      (leveldb-delete db "range-a")
      (leveldb-delete db "range-b")
      (leveldb-delete db "range-c")
      (leveldb-delete db "range-d"))

    (test-case "test in-leveldb inverted range"
      ;; When start >= limit, should return no results
      (leveldb-put db "inv-a" "val-a")
      (leveldb-put db "inv-b" "val-b")
      (def count 0)
      (for ((values k v) (in-leveldb db "inv-z" "inv-a"))
        (set! count (+ count 1)))
      (check count => 0)
      ;; Clean up
      (leveldb-delete db "inv-a")
      (leveldb-delete db "inv-b"))

    (test-case "test in-leveldb-keys"
      (leveldb-put db "konly-a" "val-a")
      (leveldb-put db "konly-b" "val-b")
      (leveldb-put db "konly-c" "val-c")
      ;; Key-only iteration
      (def keys '())
      (for (k (in-leveldb-keys db "konly-a" "konly-d"))
        (set! keys (cons (bytes->string k) keys)))
      (check (sort keys string<?) => '("konly-a" "konly-b" "konly-c"))
      ;; Clean up
      (leveldb-delete db "konly-a")
      (leveldb-delete db "konly-b")
      (leveldb-delete db "konly-c"))

    (test-case "test in-leveldb-keys with limit excluding exact key"
      ;; Limit is exclusive — keys equal to limit should not appear
      (leveldb-put db "lim-a" "val-a")
      (leveldb-put db "lim-b" "val-b")
      (leveldb-put db "lim-c" "val-c")
      (def keys '())
      (for (k (in-leveldb-keys db "lim-a" "lim-b"))
        (set! keys (cons (bytes->string k) keys)))
      ;; Only "lim-a" should appear; "lim-b" is excluded (exclusive upper bound)
      (check keys => '("lim-a"))
      ;; Clean up
      (leveldb-delete db "lim-a")
      (leveldb-delete db "lim-b")
      (leveldb-delete db "lim-c"))

    (test-case "test compact-range"
      (leveldb-put db "compact-a" "val-a")
      (leveldb-put db "compact-b" "val-b")
      ;; Compact a specific range
      (leveldb-compact-range db "compact-a" "compact-c")
      ;; Data should still be readable
      (check (bytes->string (leveldb-get db "compact-a")) => "val-a")
      (check (bytes->string (leveldb-get db "compact-b")) => "val-b")
      ;; Clean up
      (leveldb-delete db "compact-a")
      (leveldb-delete db "compact-b"))

    (test-case "test compact-range with NULL boundaries"
      ;; Full compaction with #f/#f (BUG-9 fix)
      (leveldb-put db "null-compact" "value")
      (leveldb-compact-range db #f #f)
      ;; Data should still be readable
      (check (bytes->string (leveldb-get db "null-compact")) => "value")
      ;; Partial NULL: compact from beginning to a key
      (leveldb-compact-range db #f "null-compact~")
      ;; Partial NULL: compact from a key to end
      (leveldb-compact-range db "null-compact" #f)
      ;; Clean up
      (leveldb-delete db "null-compact"))

    (test-case "test default-options"
      (def opts (leveldb-default-options))
      (check (not (not opts)) => #t)
      ;; Should return the same cached object
      (check (eq? opts (leveldb-default-options)) => #t))

    (test-case "test default-read-options"
      (def opts (leveldb-default-read-options))
      (check (not (not opts)) => #t)
      ;; Should return the same cached object
      (check (eq? opts (leveldb-default-read-options)) => #t))

    (test-case "test default-write-options"
      (def opts (leveldb-default-write-options))
      (check (not (not opts)) => #t)
      ;; Should return the same cached object
      (check (eq? opts (leveldb-default-write-options)) => #t))

    (test-case "test write-options"
      ;; Default (no sync)
      (def wo1 (leveldb-write-options))
      (check (not (not wo1)) => #t)
      ;; With sync
      (def wo2 (leveldb-write-options sync: #t))
      (check (not (not wo2)) => #t)
      ;; Verify sync writes actually work
      (leveldb-put db "sync-test" "sync-val" wo2)
      (check (bytes->string (leveldb-get db "sync-test")) => "sync-val")
      ;; Clean up
      (leveldb-delete db "sync-test"))

    (test-case "test destroy-db and repair-db"
      ;; Create a temporary database, write data, close, destroy
      (def tmp (make-temporary-file-name "test-destroy.db"))
      (def tmp-db (leveldb-open tmp))
      (leveldb-put tmp-db "key" "value")
      (leveldb-close tmp-db)
      ;; Repair the database
      (leveldb-repair-db tmp)
      ;; Verify data survives repair
      (set! tmp-db (leveldb-open tmp (leveldb-options create-if-missing: #f)))
      (check (bytes->string (leveldb-get tmp-db "key")) => "value")
      (leveldb-close tmp-db)
      ;; Destroy the database
      (leveldb-destroy-db tmp)
      ;; Verify it's gone — opening without create-if-missing should fail
      (check-exception
        (leveldb-open tmp (leveldb-options create-if-missing: #f))
        leveldb-error?))))
