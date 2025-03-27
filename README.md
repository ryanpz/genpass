# genpass

genpass is a command-line utility that generates a random passphrase.

## Usage

Running `genpass` outputs a passphrase consisting of six capitalized words suffixed with a single digit, separated by a single hyphen [-].

Example: `Hippopotamus0-Highlight2-Brainstorm9-Skeleton0-Extend7-Gallery3`

```
NAME
    genpass - generate a random passphrase

SYNOPSIS
    genpass [OPTIONS...]

OPTIONS
    -n NUM_WORDS
        Output a passphrase that is `NUM_WORDS` words long (max
        255, defaults to 6).

    -h
        Print the help output for genpass.
```

## Building

### Requirements

* `zig`
* `make`

### Make Targets

 * `build`: build the release version
 * `run`: build and run the debug version
 * `test`: run all tests
 * `codegen-wordlist`: generate zig code representing [wordlist.txt](./data/wordlist.txt) (see below)

### Configuring the Word List

To configure the list of words genpass pulls from:

 1. replace the contents of [wordlist.txt](./data/wordlist.txt) with your list of newline-separated words
 2. run `make codegen-wordlist`
 3. rebuild with `make build` or `make run`

Note: `codegen-wordlist` embeds the word list into the executable, so `wordlist.txt` isn't required for the compiled program to run.

## License

0BSD
