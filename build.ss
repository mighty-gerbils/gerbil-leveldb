#!/usr/bin/env gxi

(import :std/build-script :std/make :std/misc/process :std/misc/string)

(def (homebrew-prefix pkg)
  (try
    (string-trim-eol (run-process ["brew" "--prefix" pkg] coprocess: read-line))
    (catch _ #f)))

(def leveldb-cc-options
  (let (flags (cppflags "leveldb" #f))
    (or flags
        (let (prefix (homebrew-prefix "leveldb"))
          (if prefix
            (string-append "-I" prefix "/include")
            "")))))

(def leveldb-ld-options
  (let (flags (ldflags "leveldb" #f))
    (or flags
        (let (prefix (homebrew-prefix "leveldb"))
          (if prefix
            (string-append "-L" prefix "/lib -lleveldb")
            "-lleveldb")))))

(defbuild-script
  `((gsc: "db/_leveldb"
                "-cc-options" ,leveldb-cc-options
                "-ld-options" ,leveldb-ld-options)
          (ssi: "db/_leveldb")
          "db/leveldb"
          "db/leveldb-test"))
