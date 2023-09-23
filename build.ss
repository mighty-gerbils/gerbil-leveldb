#!/usr/bin/env gxi

(import :std/build-script :std/make)
(defbuild-script
  `((gsc: "db/_leveldb"
                "-cc-options" ,(cppflags "leveldb" "")
                "-ld-options" ,(ldflags "leveldb" "-lleveldb"))
          (ssi: "db/_leveldb")
          "db/leveldb"))
