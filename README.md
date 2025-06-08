# scr

This repository contains various media and automation scripts.

## Running tests

Bats test suites live under the `media/` and `media/ffx_modules/` directories.
They rely on the [`bats-support`](https://github.com/bats-core/bats-support) and
[`bats-assert`](https://github.com/bats-core/bats-assert) helper libraries. Install
these packages or clone the libraries locally before running `bats`:

```sh
sudo apt-get install bats bats-support bats-assert
# or clone locally
# git clone https://github.com/bats-core/bats-support.git media/bats-support
# git clone https://github.com/bats-core/bats-assert.git media/bats-assert
```

