# multipull

[![Gem Version](https://badge.fury.io/rb/multipull.svg)](https://badge.fury.io/rb/multipull)

Ruby implementation of [multipull](https://dev.to/rmpato/git-pull-multiple-repositories-at-once-4l68).

## Installation

```sh
gem install multipull
```

## Usage

```sh
multipull
```

```sh
multipull ~/Ruby # directory
```

## What is this?

The name of the command multipull was borrowed from the following article.

[Git pull multiple repositories at once](https://dev.to/rmpato/git-pull-multiple-repositories-at-once-4l68) by [@rmpato](https://github.com/rmpato)

```sh
alias multipull="find . -mindepth 1 -maxdepth 1 -type d -print -exec git -C {} pull \;"
```

The following pages include some great one-liners.

[Run git pull over all subdirectories](https://stackoverflow.com/questions/3497123/run-git-pull-over-all-subdirectories#12495234).

```sh
find . -type d -depth 1 -exec git --git-dir={}/.git --work-tree=$PWD/{} pull origin master \;
```

```sh
ls | xargs -I{} git -C {} pull
ls | xargs -P10 -I{} git -C {} pull
```

```sh
git config --global alias.all '!f() { ls -R -d */.git | xargs -I{} bash -c "echo {} && git -C {}/../ $1"; }; f'
```

```sh
for i in */.git; do ( echo $i; cd $i/..; git pull; ); done
```

While these one-liners are nice, this multipull gem is better in the following ways

1. No need to remember one-liners. `gem install multipull` is easier than writing alias in bashrc.
2. No need to modify scripts for each OS.
3. Options can be added as needed.

## Development

PR welcome. 

If you would like to become an owner and take over the development, please contact me with a pull request.

## LICENSE

MIT
