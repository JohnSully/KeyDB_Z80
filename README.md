# NoSQL For 8-bit Microcomputers

For when DBase just won't do!

What is this?
-------------

The NoSQL database craze has made waves on the mainframe and large computer markets, but so far no software package has been made available for the home hobbyist.

Based upon its [bigger brother](https://github.com/JohnSully/KeyDB), KeyDB 8-bit edition brings the power of NoSQL to Z80 microcomputers.  Supporting a whopping 240 keys, and a diverse command set of PING, SET, and GET KeyDB 8-bit is sure to satisfy your NoSQL needs.

Does it actually work?
----------------------

<img src="./KeyDB.png" width=300 height=400 align="right" />

It may be hard to believe but we have indeed fit the power of [KeyDB](https://github.com/JohnSully/KeyDB) in an 8-bit package.  Needing just 32KB of RAM this server supports both get and set commands!
Best of all as a NoSQL database, you won't have to type a line of that nasty SQL.

KeyDB 8-bit is able to achieve a whopping 10 queries per second on our 4Mhz Z80!  

How can I try it?
-----------------

KeyDB 8-bit is compiled on a much larger UNIX or Linux machine.  For convenience instructions are provided for Debian and Ubuntu distributions.  Contact your UNIX vendor for additional information.

#### Add Dependencies ####
    % sudo apt install z80asm z80ex-dev
    
#### Building ####
The compilation step will assemble both KeyDB itself, and the emulator for local testing.  Simply run:

    % make
    
#### Testing ####
KeyDB 8-bit works with the tools of its larger brother KeyDB and Redis.  Running make run will launch an emulated server on the default port.  After which you will be able to connect with redis-cli, or even redis-benchmark

    % make run
    
Then on a different terminal:

    % ./redis-cli
    
OR
    
    % ./redis-benchmark -t get -c 1
    
LICENSE
-------

KeyDB 8-bit is licensed under the Bill Gates License.  For more details see the [LICENSE](./LICENSE) file.

Porting
-------

KeyDB is designed for our specific IMSAI with its upgraded Z80 CPU card, but porting is trivial for any machine with an 8250.  Simply change the ioport at the top of keydb.asm to the base address of your 80250 compatible UART.  For more complex machines all IO is routed through the getch and putch routines which can be modified to suit your needs.

Note that KeyDB expects the UART to be initialized before it is started.  KeyDB will not modify your baud rate and other settings.
