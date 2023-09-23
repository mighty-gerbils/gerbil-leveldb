# Gerbil LevelDB Driver

This package provides a Gerbil LevelDB driver using `libleveldb`.

## Dependencies

You need to have `libleveldb` installed in your system.

## Installation

To install the package in your `$GERBIL_PATH` (`~/.gerbil` by default):
```shell
$ gerbil pkg install github.com/might-gerbils/gerbil-leveldb
```

## API
To use bindings from this package:
```scheme
(import :clan/db/leveldb)
```

## leveldb-error?

```
(leveldb-error? ...)
```


Please document me!

## leveldb?

```
(leveldb? ...)
```


Please document me!

## leveldb-open

```
(leveldb-open ...)
```


Please document me!

## leveldb-close

```
(leveldb-close ...)
```


Please document me!

## leveldb-put

```
(leveldb-put ...)
```


Please document me!

## leveldb-get

```
(leveldb-get ...)
```


Please document me!

## leveldb-delete

```
(leveldb-delete ...)
```


Please document me!

## leveldb-write

```
(leveldb-write ...)
```


Please document me!

## leveldb-key?

```
(leveldb-key? ...)
```


Please document me!

## leveldb-writebatch

```
(leveldb-writebatch ...)
```


Please document me!

## leveldb-writebatch-clear

```
(leveldb-writebatch-clear ...)
```


Please document me!

## leveldb-writebatch-put

```
(leveldb-writebatch-put ...)
```


Please document me!

## leveldb-writebatch-delete

```
(leveldb-writebatch-delete ...)
```


Please document me!

## leveldb-iterator

```
(leveldb-iterator ...)
```


Please document me!

## leveldb-iterator-close

```
(leveldb-iterator-close ...)
```


Please document me!

## leveldb-iterator-valid?

```
(leveldb-iterator-valid? ...)
```


Please document me!

## leveldb-iterator-seek-first

```
(leveldb-iterator-seek-first ...)
```


Please document me!

## leveldb-iterator-seek-last

```
(leveldb-iterator-seek-last ...)
```


Please document me!

## leveldb-iterator-seek

```
(leveldb-iterator-seek ...)
```


Please document me!

## leveldb-iterator-next

```
(leveldb-iterator-next ...)
```


Please document me!

## leveldb-iterator-prev

```
(leveldb-iterator-prev ...)
```


Please document me!

## leveldb-iterator-key

```
(leveldb-iterator-key ...)
```


Please document me!

## leveldb-iterator-value

```
(leveldb-iterator-value ...)
```


Please document me!

## leveldb-iterator-error

```
(leveldb-iterator-error ...)
```


Please document me!

## in-leveldb

```
(in-leveldb ...)
```


Please document me!

## in-leveldb-keys

```
(in-leveldb-keys ...)
```


Please document me!

## leveldb-compact-range

```
(leveldb-compact-range ...)
```


Please document me!

## leveldb-destroy-db

```
(leveldb-destroy-db ...)
```


Please document me!

## leveldb-repair-db

```
(leveldb-repair-db ...)
```


Please document me!

## leveldb-options

```
(leveldb-options ...)
```


Please document me!

## leveldb-default-options

```
(leveldb-default-options ...)
```


Please document me!

## leveldb-read-options

```
(leveldb-read-options ...)
```


Please document me!

## leveldb-default-read-options

```
(leveldb-default-read-options ...)
```


Please document me!

## leveldb-write-options

```
(leveldb-write-options ...)
```


Please document me!

## leveldb-default-write-options

```
(leveldb-default-write-options ...)
```


Please document me!

# License and Copyright

© 2017-2023 The Gerbil Core Team and contributors; License: LGPLv2.1 and Apache 2.0

Originally written by vyzo.
