# sermon

This program purpose is to monitor your system
health using standard Linux tools. Therefore
Linux is required.

The idea of the program is to run it on your **ser**ver
and **mon**itor the health. Which is also the reason
for the name **sermon**.

The program can run on your local machine
or on your server. The best way to run the program
is by adding it as a system service.

## Usage
```
 sermon [options]
```


## Options
```
 -h, --help          Show this output
 -c, --config        Prints the path to your config file
 -s, --show          Prints the current health to the console
 -cs, --clustershow  Prints the current health of all nodes in cluster
 -cp, --clusterping  Checks the connection to the cluster nodes
 -ms, --mailstatus   Send a mail with health to emails in config
```


## Config file
The config file (`config.cfg`) is where you specify
the details which sermon use.

To disable integers, set them to 0.


## Cluster
The current GIT repo does not support the cluster
parameter. The purpose of the cluster if to give
you 1 place to monitor all of your sermon instances.

Currently you can only access the cluster in
the WWW-view - terminal is not supported.

______

*This README is generated with [Nim to Markdown](https://github.com/ThomasTJdev/nimtomd)*
