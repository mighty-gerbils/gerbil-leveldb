#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; Functional integration test for gerbil-leveldb
;;; This test creates a real database and exercises all features.

(import :std/format
        :std/os/temporaries
        :std/sugar
        :std/values
        :std/iter
        :clan/db/leveldb)

(def (main . args)
  (displayln "=== Gerbil LevelDB Functional Test ===")
  (displayln)
  
  ;; Create temporary database
  (def db-path (make-temporary-file-name "leveldb-functional-test"))
  (displayln "Database path: " db-path)
  (displayln)
  
  ;; Track test results
  (def tests-passed 0)
  (def tests-failed 0)
  
  (def (pass name)
    (set! tests-passed (+ tests-passed 1))
    (displayln "✓ " name))
  
  (def (fail name msg)
    (set! tests-failed (+ tests-failed 1))
    (displayln "✗ " name ": " msg))
  
  (def (check name condition)
    (if condition
      (pass name)
      (fail name "condition failed")))
  
  (def (check-equal name actual expected)
    (if (equal? actual expected)
      (pass name)
      (fail name (format "expected ~a, got ~a" expected actual))))
  
  (def db #f)
  (def repair-path #f)

  (try
    ;; === Test 1: Version ===
    (displayln "--- Version ---")
    (defvalues (major minor) (leveldb-version))
    (check "leveldb-version returns major" (and (fixnum? major) (>= major 1)))
    (check "leveldb-version returns minor" (fixnum? minor))
    (displayln "  LevelDB version: " major "." minor)
    (displayln)

    ;; === Test 2: Options ===
    (displayln "--- Options ---")
    (def opts (leveldb-options
                create-if-missing: #t
                write-buffer-size: 4194304      ;; 4MB
                max-open-files: 100
                block-size: 4096
                max-file-size: 2097152          ;; 2MB (new feature)
                bloom-filter-bits: 10
                compression: #t))
    (check "leveldb-options with max-file-size" opts)
    (displayln)

    ;; === Test 3: Environment ===
    (displayln "--- Environment ---")
    (def env (leveldb-default-env))
    (check "leveldb-default-env" env)
    (def test-dir (leveldb-env-test-directory env))
    (check "leveldb-env-test-directory" test-dir)
    (displayln "  Test directory: " test-dir)

    ;; Options with env
    (def opts-with-env (leveldb-options env: env))
    (check "leveldb-options with env:" opts-with-env)
    (displayln)

    ;; === Test 4: Open Database ===
    (displayln "--- Open Database ---")
    (set! db (leveldb-open db-path opts))
    (check "leveldb-open" (leveldb? db))
    (displayln)

    ;; === Test 5: Basic Put/Get/Delete ===
    (displayln "--- Basic Operations ---")
    (leveldb-put db "key1" "value1")
    (leveldb-put db "key2" "value2")
    (leveldb-put db "key3" "value3")
    (check-equal "leveldb-get key1" (bytes->string (leveldb-get db "key1")) "value1")
    (check-equal "leveldb-get key2" (bytes->string (leveldb-get db "key2")) "value2")
    (check "leveldb-key? existing" (leveldb-key? db "key1"))
    (check "leveldb-key? non-existing" (not (leveldb-key? db "nonexistent")))

    (leveldb-delete db "key3")
    (check-equal "leveldb-delete" (leveldb-get db "key3") #f)
    (displayln)

    ;; === Test 6: Write Batch ===
    (displayln "--- Write Batch ---")
    (def wb (leveldb-writebatch))
    (check "leveldb-writebatch" wb)
    (leveldb-writebatch-put wb "batch1" "bvalue1")
    (leveldb-writebatch-put wb "batch2" "bvalue2")
    (leveldb-writebatch-put wb "batch3" "bvalue3")
    (leveldb-writebatch-delete wb "key2")
    (leveldb-write db wb)
    (check-equal "writebatch put batch1" (bytes->string (leveldb-get db "batch1")) "bvalue1")
    (check-equal "writebatch delete key2" (leveldb-get db "key2") #f)
    (displayln)

    ;; === Test 7: Write Batch Append ===
    (displayln "--- Write Batch Append ---")
    (def wb1 (leveldb-writebatch))
    (def wb2 (leveldb-writebatch))
    (leveldb-writebatch-put wb1 "append-a" "from-wb1")
    (leveldb-writebatch-put wb2 "append-b" "from-wb2")
    (leveldb-writebatch-put wb2 "append-c" "from-wb2")
    (leveldb-writebatch-append wb1 wb2)
    (leveldb-write db wb1)
    (check-equal "append: key from wb1" (bytes->string (leveldb-get db "append-a")) "from-wb1")
    (check-equal "append: key from wb2 (1)" (bytes->string (leveldb-get db "append-b")) "from-wb2")
    (check-equal "append: key from wb2 (2)" (bytes->string (leveldb-get db "append-c")) "from-wb2")
    (displayln)

    ;; === Test 8: Snapshots ===
    (displayln "--- Snapshots ---")
    (leveldb-put db "snap-key" "before-snapshot")
    (def snap (leveldb-snapshot db))
    (check "leveldb-snapshot" snap)

    ;; Modify after snapshot
    (leveldb-put db "snap-key" "after-snapshot")
    (leveldb-put db "snap-new" "new-after-snapshot")

    ;; Read current vs snapshot
    (check-equal "current value" (bytes->string (leveldb-get db "snap-key")) "after-snapshot")
    (def snap-opts (leveldb-read-options snapshot: snap))
    (check-equal "snapshot value" (bytes->string (leveldb-get db "snap-key" snap-opts)) "before-snapshot")
    (check-equal "snapshot: new key not visible" (leveldb-get db "snap-new" snap-opts) #f)

    (leveldb-snapshot-release db snap)
    (check "leveldb-snapshot-release" #t)
    (displayln)

    ;; === Test 9: Iterators ===
    (displayln "--- Iterators ---")
    (def iter (leveldb-iterator db))
    (check "leveldb-iterator" iter)
    (check "iterator not valid initially" (not (leveldb-iterator-valid? iter)))

    (leveldb-iterator-seek-first iter)
    (check "iterator valid after seek-first" (leveldb-iterator-valid? iter))

    ;; Count keys
    (def key-count 0)
    (let loop ()
      (when (leveldb-iterator-valid? iter)
        (set! key-count (+ key-count 1))
        (leveldb-iterator-next iter)
        (loop)))
    (check "iterator traversed keys" (> key-count 0))
    (displayln "  Keys found: " key-count)

    (leveldb-iterator-close iter)
    (displayln)

    ;; === Test 10: in-leveldb iteration ===
    (displayln "--- in-leveldb iteration ---")
    (def iter-keys '())
    (for ((values k v) (in-leveldb db))
      (set! iter-keys (cons (bytes->string k) iter-keys)))
    (check "in-leveldb iterates" (> (length iter-keys) 0))
    (displayln "  Keys via in-leveldb: " (length iter-keys))

    ;; in-leveldb-keys
    (def key-only-count 0)
    (for (k (in-leveldb-keys db))
      (set! key-only-count (+ key-only-count 1)))
    (check-equal "in-leveldb-keys count matches" key-only-count (length iter-keys))
    (displayln)

    ;; === Test 11: Properties ===
    (displayln "--- Properties ---")
    (def stats (leveldb-property db "leveldb.stats"))
    (check "leveldb-property stats" stats)
    (def sstables (leveldb-property db "leveldb.sstables"))
    (check "leveldb-property sstables" sstables)
    (check-equal "leveldb-property invalid" (leveldb-property db "invalid.prop") #f)
    (displayln)

    ;; === Test 12: Approximate Size ===
    (displayln "--- Approximate Size ---")
    (def size (leveldb-approximate-size db "" "~"))
    (check "leveldb-approximate-size" (>= size 0))
    (displayln "  Approximate size (all keys): " size " bytes")

    (def size-range (leveldb-approximate-size db "batch" "batch~"))
    (check "leveldb-approximate-size range" (>= size-range 0))
    (displayln "  Approximate size (batch*): " size-range " bytes")
    (displayln)

    ;; === Test 13: Compact Range ===
    (displayln "--- Compact Range ---")
    (leveldb-compact-range db "" "~")
    (check "leveldb-compact-range" #t)
    (displayln)

    ;; === Test 14: Sync Writes ===
    (displayln "--- Sync Writes ---")
    (def sync-opts (leveldb-write-options sync: #t))
    (leveldb-put db "sync-key" "sync-value" sync-opts)
    (check-equal "sync write" (bytes->string (leveldb-get db "sync-key")) "sync-value")
    (displayln)

    ;; === Test 15: Read Options ===
    (displayln "--- Read Options ---")
    (def read-opts (leveldb-read-options verify-checksums: #t fill-cache: #t))
    (check-equal "read with options" (bytes->string (leveldb-get db "key1" read-opts)) "value1")
    (displayln)

    ;; === Close and Destroy ===
    (displayln "--- Cleanup ---")
    (leveldb-close db)
    (set! db #f)
    (check "leveldb-close" #t)

    (leveldb-destroy-db db-path)
    (check "leveldb-destroy-db" #t)
    (displayln)

    ;; === Test 16: Repair (on fresh db) ===
    (displayln "--- Repair ---")
    (set! repair-path (make-temporary-file-name "leveldb-repair-test"))
    (def rdb (leveldb-open repair-path))
    (leveldb-put rdb "test" "value")
    (leveldb-close rdb)
    (leveldb-repair-db repair-path)
    (check "leveldb-repair-db" #t)
    (leveldb-destroy-db repair-path)
    (set! repair-path #f)
    (displayln)

    (catch (e)
      (displayln "ERROR: " e)
      (set! tests-failed (+ tests-failed 1)))
    (finally
      ;; Best-effort cleanup of any open databases on error
      (when db
        (try (leveldb-close db) (catch _ (void)))
        (try (leveldb-destroy-db db-path) (catch _ (void))))
      (when repair-path
        (try (leveldb-destroy-db repair-path) (catch _ (void))))))
  
  ;; Summary
  (displayln "=== Test Summary ===")
  (displayln "Passed: " tests-passed)
  (displayln "Failed: " tests-failed)
  (displayln)
  
  (if (= tests-failed 0)
    (begin
      (displayln "All tests PASSED!")
      (exit 0))
    (begin
      (displayln "Some tests FAILED!")
      (exit 1))))

(apply main (cdr (command-line)))
