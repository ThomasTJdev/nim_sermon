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

## System health vs Continuously monitoring
You can monitor you system in 2 ways. Either getting 1 or more
daily notifications, or continuously monitoring various
system parameters.

To activate continuously monitoring disable:
   `dailyInfo = "false"` in the config.cfg
Otherwise the daily notification is enabled.


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

To enable cluster, compile with `-d:cluster`

# Example output
```
 $ sermon -s

 ----------------------------------------
            System status
 ----------------------------------------
 Last boot:    system boot  2018-10-27 06:43
 Uptime:       10:25:07 up  3:42,  1 user,  load average: 1,00, 1,00, 0,88
 System:       Linux sys 4.18.16-arch1-1-ARCH
 Hostname:     myHostname
 Public IP:    80.80.80.80
 Mem total:    1.028MB
 Mem occupied: 0.298453125MB
 Mem free:     0.488MB
 Nim verion:   0.19.4
 Compile time: 10:49:10
 Compile data: 2019-03-16

 ----------------------------------------
               Memory usage
 ----------------------------------------
 Error:   Mem:   Usage: 3,0Gi - Limit: 2.0
 Success: Swap:  Usage: 0,0Ki - Limit: 1000.0

 ----------------------------------------
               Process status
 ----------------------------------------
 Error:   nginx      : is inactive (dead)
 Success: sshd       : is active (running)
 Info:    servermon  : is not a service

 ----------------------------------------
               Memory per process
 ----------------------------------------
 Error:   nginx      : 26 > 20MB
 Success: sshd       : 23 < 25MB

 ----------------------------------------
               Space usage
 ----------------------------------------
 Error:   You have reached your warning storage level at 40

 Success: Filesystem                           Size  Used Avail Use% Mounted on
 Success: dev                                  6,8G     0  6,8G   0% /dev
 Success: run                                  6,8G  1,3M  6,8G   1% /run
 Error:   /dev/mapper/AntergosVG-AntergosRoot  600G  150G  150G  50% /
 Success: tmpfs                                5,8G   24M  5,7G   1% /dev/shm
 Success: /dev/sda1                            243M   76M  151M  34% /boot

 ----------------------------------------
               URL health
 ----------------------------------------
 Error:   301 - https://redirecturl.com
 Success: 200 - https://nim-lang.org
```

*README is generated with [Nim to Markdown](https://github.com/ThomasTJdev/nimtomd)*
