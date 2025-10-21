# Bitkub Chain (PoS) Configuration

### Hardware Requirements

Minimum:

* CPU with 2+ cores
* 4GB RAM
* 1TB free storage space to sync the Mainnet
* 10 MBit/sec download Internet service

Recommended:

* Fast CPU with 8+ cores
* 32GB+ RAM
* High-performance SSD with at least 1TB of free space
* 50+ MBit/sec download Internet service

### Download Geth
```bash
# Linux amd64
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest |grep browser_ |grep linux-amd64 |cut -d\" -f4) -o geth.linux-amd64.tar.gz
$ tar -xf geth.linux-amd64.tar.gz
$ chmod -v u+x geth

# Linux arm64
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest |grep browser_ |grep linux-arm64 |cut -d\" -f4) -o geth.linux-arm64.tar.gz
$ tar -xf geth.linux-arm64.tar.gz
$ chmod -v u+x geth

# MacOS Intel
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest |grep browser_ |grep darwin-amd64 |cut -d\" -f4) -o geth.darwin-amd64.tar.gz
$ tar -xf geth.darwin-amd64.tar.gz
$ chmod -v u+x geth

# MacOS Silicon
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest |grep browser_ |grep darwin-arm64 |cut -d\" -f4) -o geth.darwin-arm64.tar.gz
$ tar -xf geth.darwin-arm64.tar.gz
$ chmod -v u+x geth
```

### Download Config/Genesis
```bash
# Mainnet
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc-node/releases/latest |grep browser_ |grep mainnet |cut -d\" -f4) -o mainnet.tar.gz
$ tar -xf mainnet.tar.gz

# Testnet
$ curl -L $(curl -s https://api.github.com/repos/kub-chain/bkc-node/releases/latest |grep browser_ |grep testnet |cut -d\" -f4) -o testnet.tar.gz
$ tar -xf testnet.tar.gz
```

### Running a Validator
```bash
# Initial Genesis Block
$ ./geth --datadir ./data init genesis.json

# Generate account password
$ echo "<<YourPassword>>" > ./data/password.sec

# Generate new account
$ ./geth account new  --datadir ./data --password ./data/password.sec

# Run
$ ./geth --datadir ./data --config ./config.toml \
  --syncmode snap \
  --password ./data/password.sec \
  --mine --unlock <<YourAccountPublicAddressFromPreviousStep>> \ 
  --allow-insecure-unlock
```


### Running a Fullnode

```bash
# Initial Genesis Block
$ ./geth --datadir ./data init ./genesis.json

# Run
$ ./geth --datadir ./data --config ./config.toml --syncmode full
```


### Running a Archivenode

```bash
# Initial Genesis Block
$ ./geth --datadir ./data init ./genesis.json

# Run 
$ ./geth --datadir ./data --config ./config.toml  --syncmode full --gcmode archive
```
