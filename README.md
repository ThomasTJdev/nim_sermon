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

To enable cluster, compile with `-d:cluster`

# Example output
```
 $ sermon -s

 ----------------------------------------
            System status
 ----------------------------------------
 Last boot:  system boot  2018-10-27 06:43
 Uptime:     10:25:07 up  3:42,  1 user,  load average: 1,00, 1,00, 0,88
 System:     Linux sys 4.18.16-arch1-1-ARCH

 ----------------------------------------
               Memory usage
 ----------------------------------------
 Error:   Mem: Usage: 3,0Gi - Limit: 2.0
 Success: Swap: Usage: 0B - Limit: 1000.0

 ----------------------------------------
               Memory per process
 ----------------------------------------
 Error:   nginx=26Mb > 20
 Success: sshd=23Mb < 25
 Error:   servermon=23Mb > 2


 ----------------------------------------
               Process status
 ----------------------------------------
 Error:   ● nginx.service - Active: inactive (dead)
 Error:   ● sshd.service - Active: inactive (dead)
 Info:    servermon is not a service

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
