# multipull

Ruby implementation of multipull

## installation

```sh
gem install multipull
```

## What is this?

The original implementation is here.

[Git pull multiple repositories at once](https://dev.to/rmpato/git-pull-multiple-repositories-at-once-4l68) by [@rmpato](https://github.com/rmpato)

```
alias multipull="find . -mindepth 1 -maxdepth 1 -type d -print -exec git -C {} pull \;"
```

## Development

PR welcome. 

If you would like to become an owner and take over the development, please contact me with a pull request.

## LICENSE

MIT
