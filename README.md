# MSX JSON Parser

A small library to parse JSON files under MSX BASIC.

## Rationale

There are many network cartridges available for MSX. You may want to use them to connect to the many REST endpoints around us, but many of them only communicate in JSON. This lib provides JSON parsing capabilities to fill this gap.

The lib was designed to blend with MSX BASIC idiomatically, and it uses a macro command interface just like PLAY and DRAW to achieve this goal.

## Features

* Install with `BLOAD "JSON.BIN",R`. This will install three API calls into the `DEFUSR` user routines.
* Optimized for size. The entire lib fits under 1kb.
* Not relocatable. Provided binary loads from `0xD000`, but you can change the `ORG` in the source file if you need a different start address.
* JSON file must be loaded into BASIC-visible memory (`0x8000-0xFFFF`).
* JSON parsing follows [RFC 7159](https://tools.ietf.org/html/rfc7159) to the letter. Take care with caveats of the format (integers may not start with a 0, strings must always use double-quotes instead of single quotes, trailing commas before closing an array is not allowed, etc).
* No extra memory beyond the lib itself. No additional data structures are created when parsing the JSON, to minimize memory usage. However, all lib calls are O(n) in the size of the JSON file.

## Usage

There are three calls available in the API:

* `S=USR(ADDR)`: Sets JSON start address.
* `T=USR1(Q$)`: Gets the type of the JSON token pointed by query Q$.
* `V$=USR2(Q$)`: Gets the value of the JSON token pointer by query Q$ as a string.
