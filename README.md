# Solo GPU mining on a local Ycash node

ycash-stratum bridges the gap between a GPU miner (ie: gminer) and a ycashd node, which allow you to solo-mine YEC without using a public pool.

Solo mining isn't for everyone, finding a block is HARD so if you only have a few GPUs it won't happen often, but when it does you get the entire block reward plus any transaction fees.


To use this you must :- 
- install ycashd
- create a shielded address (ys1) ON THE NODE

Your ycash.conf file should look like this :- 

```
mainnet=1
server=1
listen=1
addnode=mainnet.ycash.xyz
rpcport=8832
rpcuser=not_telling_you
rpcpassword=not_telling_you_this either!
zmqpubhashblock=ipc:///tmp/ycash.block.raw
minetolocalwallet=1
mineraddress=ys1_change_to_your_shielded_ycash_address
```

NOTE: ycash-stratum has to run as root, its a server that opens network sockets

ycash-stratum datadir=/full/path/to/ycash/directory client=/full/path/to/ycash-cli

Now point your miner at the nodes IP address & port 3333


