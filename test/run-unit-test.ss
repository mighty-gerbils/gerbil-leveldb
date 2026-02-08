#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; Runner for leveldb unit tests
;;; Usage: GERBIL_LOADPATH=.gerbil/lib gxi test/run-unit-test.ss

(import :std/test
        :clan/db/leveldb-test)

(def (main . args)
  (test-setup!)
  (run-tests! leveldb-test)
  (test-cleanup!)
  (test-report-summary!))

(apply main (cdr (command-line)))
