# Vera3 Animal Social Club Contracts

## Usage

If you have Nix, you can use this project's flake to spin up a development environment:

```
nix develop
```

Otherwise, you'll need [foundry](https://getfoundry.sh/) installed on your system to build this project.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
