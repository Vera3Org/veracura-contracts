# Vera3 Animal Social Club Contracts

## Usage

If you have Nix, you can use this project's flake to spin up a development environment:

```
nix develop
```

Otherwise, you'll need [foundry](https://getfoundry.sh/) installed on your system to build this project.

### Local development server

Local development needs two steps: spinning up a local RPC, and deploying our contracts on it.

To start a local RPC with a fork of Base Sepolia testnet, you can open a terminal and run the following command, which will start a server listening at the RPC URL `http://127.0.0.1:8545`:
```sh
anvil --fork-url https://base-sepolia.blockpi.network/v1/rpc/public --chain-id 84532
```

Then, to deploy our contracts, run:

```sh
bash deploy_local.sh
```

A bunch of confirmed transaction should be printed. Scroll up past them and you'll find something like:

```
Script ran successfully.

== Logs ==
  Done. Animal Social Club Manager address:  0x829828604A09CcC381f3080e4aa5557b42C4c87A

## Setting up 1 EVM.

==========================
...
```

This means that the address of the deployed contract is 0x829828604A09CcC381f3080e4aa5557b42C4c87A.

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
